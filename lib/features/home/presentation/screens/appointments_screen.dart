import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../blocs/appointments/appointments_bloc.dart';
import '../widgets/appointment_card.dart';

/// The "Mis citas" tab — what is booked.
///
/// Split into upcoming and past by a segmented control rather than by two
/// scrolling sections, because the two answer different questions ("when do I
/// have to be there?" vs "when was I last seen?") and mixing them makes the
/// first one harder.
///
/// ## Two blocs, one per tab
///
/// Each list owns an [AppointmentsBloc] fixed to its own scope. A single bloc
/// that reloaded on every tab change would refetch data it already had every
/// time the patient looked back and forth, and would show a spinner each time.
///
/// They are created HERE rather than by a `BlocProvider`, for two reasons that
/// are really one: `MultiBlocProvider` cannot hold two providers of the same
/// type, and the past list should not be fetched until the tab is opened. Owned
/// by hand means closed by hand — see [dispose].
///
/// ## The empty state is shown on `isEmpty`, never on a failure
///
/// A new account has zero appointments, and an empty tab that shows only
/// background colour reads as a failed load — so the empty state offers the way
/// out. But telling a patient "no tienes citas agendadas" when the REQUEST
/// failed is the single most damaging thing this screen can say, so a failure
/// gets its own branch with a retry.
///
/// ## Pull-to-refresh reloads the OPEN tab, not both
///
/// The gesture belongs to the list under the finger. Reloading the tab the
/// patient is not looking at would spend a request — one per status, see
/// `AppointmentsRemoteDataSource` — on a list nobody asked to see, and it
/// would do it while a "Pasadas" bloc may not even exist yet.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static const List<String> _filters = <String>['Próximas', 'Pasadas'];

  late final AppointmentsBloc _upcoming =
      sl<AppointmentsBloc>(param1: AppointmentScope.upcoming)
        ..add(const AppointmentsRequested());

  /// Lazily built the first time "Pasadas" is opened: a patient who never taps
  /// it never pays for that request.
  AppointmentsBloc? _past;

  int _filter = 0;

  @override
  void dispose() {
    _upcoming.close();
    _past?.close();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _filter = index;
      if (index == 1) {
        _past ??= sl<AppointmentsBloc>(param1: AppointmentScope.past)
          ..add(const AppointmentsRequested());
      }
    });
  }

  /// Drives the pull-to-refresh gesture: fires a reload on [bloc] and waits
  /// for it to settle, so the spinner stays up for exactly as long as the
  /// request does. Returning immediately would snap it away before the new
  /// list arrived, which reads as "nothing happened".
  ///
  /// The bloc is passed in rather than read from the context because this
  /// screen OWNS both of them — see the class doc for why only the open one
  /// reloads.
  Future<void> _refresh(AppointmentsBloc bloc) {
    final Future<AppointmentsState> settled = bloc.stream.firstWhere(
      (AppointmentsState state) => state.status != AppointmentsStatus.loading,
    );
    bloc.add(const AppointmentsRequested());
    return settled;
  }

  @override
  Widget build(BuildContext context) {
    final bool upcomingTab = _filter == 0;
    final AppointmentsBloc bloc = upcomingTab ? _upcoming : _past!;
    final AppointmentScope scope = upcomingTab
        ? AppointmentScope.upcoming
        : AppointmentScope.past;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(bloc),
        child: SingleChildScrollView(
          // Without this the gesture is dead whenever the content is shorter
          // than the viewport — which is exactly the empty and error states,
          // the two where a patient most wants to pull again.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppSpacing.pad,
            right: AppSpacing.pad,
            top: AppSpacing.sectionY * 0.5,
            bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.section,
            children: <Widget>[
              const AppSectionHeading(
                kicker: 'Tus turnos',
                title: 'Mis citas.',
              ),

              AppSegmented(
                options: _filters,
                selectedIndex: _filter,
                onChanged: _select,
              ),

              BlocProvider<AppointmentsBloc>.value(
                value: bloc,
                // Keyed by scope so switching tabs rebuilds the subtree
                // instead of animating one list's state into the other's.
                child: AppointmentsList(
                  key: ValueKey<AppointmentScope>(scope),
                  scope: scope,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One list of appointments, driven by whichever [AppointmentsBloc] is above it.
///
/// Public because "Historial" renders the same list with a different scope.
class AppointmentsList extends StatelessWidget {
  const AppointmentsList({super.key, required this.scope, this.emptyState});

  final AppointmentScope scope;

  /// Overrides the default empty copy. "Historial" says something different
  /// from "Mis citas" about the same absence of rows.
  final Widget? emptyState;

  bool get _isUpcoming => scope == AppointmentScope.upcoming;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AppointmentsBloc, AppointmentsState>(
      // A dead token is not this screen's problem to solve. It reports it and
      // lets the router do what it already knows how to do; showing
      // "Reintentar" over an expired session would retry forever.
      listenWhen: (AppointmentsState previous, AppointmentsState current) =>
          current.isSessionExpired && !previous.isSessionExpired,
      listener: (BuildContext context, AppointmentsState state) {
        context.read<AuthBloc>().add(const AuthSessionExpired());
      },
      builder: (BuildContext context, AppointmentsState state) {
        if (state.isFirstLoad) return const _AppointmentsSkeleton();

        if (state.status == AppointmentsStatus.failure &&
            !state.isReloadFailure) {
          return _LoadFailure(
            message: state.failure?.message ?? 'No pudimos cargar tus citas.',
            onRetry: () => context.read<AppointmentsBloc>().add(
              const AppointmentsRequested(),
            ),
          );
        }

        if (state.isEmpty) {
          return emptyState ??
              AppEmptyState(
                icon: AppIcons.appointments,
                title: _isUpcoming
                    ? 'No tienes citas agendadas'
                    : 'Todavía no tienes citas pasadas',
                message: _isUpcoming
                    ? 'Cuando reserves un turno lo vas a ver acá, con la hora '
                          'exacta y la sede.'
                    : 'Acá van a quedar las consultas que ya pasaron.',
                actionLabel: _isUpcoming ? 'Agendar una cita' : null,
                // Switches tabs instead of pushing a route: the booking screen
                // already exists as a branch, and pushing a second copy over
                // the shell would hide the nav the user needs.
                onAction: _isUpcoming
                    ? () => StatefulNavigationShell.of(context).goBranch(0)
                    : null,
              );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.section,
          children: <Widget>[
            // A pull-to-refresh that failed with a list already on screen —
            // see `AppointmentsState.isReloadFailure`. The list stays up;
            // this line is the only thing that changes.
            if (state.isReloadFailure)
              Text(
                state.failure?.message ??
                    'No pudimos actualizar tus citas.',
                style: AppTypography.cap.copyWith(color: AppColors.emergency),
              ),

            for (final Appointment item in state.items)
              _AppointmentTile(
                appointment: item,
                isCancelling: state.cancellingId == item.id,
                cancelError: state.cancelFailureId == item.id
                    ? state.cancelFailure
                    : null,
              ),
          ],
        );
      },
    );
  }
}

/// Maps one [Appointment] onto the existing card.
///
/// The domain has five statuses and the card has four pills, and the collapse
/// is deliberate: `pending` and `waiting` both read as "por confirmar" to a
/// patient — the difference between them is where the clinic filed the turn
/// internally, which is not something a patient can act on.
class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.isCancelling,
    this.cancelError,
  });

  final Appointment appointment;

  /// True while THIS appointment's cancel request is in flight. Only this
  /// card's button reacts — the rest of the list stays tappable.
  final bool isCancelling;

  /// Set only when the last cancel attempt for THIS appointment failed. See
  /// `AppointmentsState.cancelFailureId` for why it is keyed by id instead of
  /// being a single flag the whole list would share.
  final Failure? cancelError;

  AppointmentStatus get _cardStatus => switch (appointment.status) {
    TurnStatus.pending || TurnStatus.waiting => AppointmentStatus.pending,
    TurnStatus.inTreatment => AppointmentStatus.confirmed,
    TurnStatus.treated => AppointmentStatus.attended,
    TurnStatus.cancelled => AppointmentStatus.cancelled,
    // An unrecognised status shows as confirmed rather than hiding the row:
    // the appointment exists, and dropping it would be worse than a pill that
    // is merely imprecise.
    TurnStatus.unknown => AppointmentStatus.confirmed,
  };

  @override
  Widget build(BuildContext context) {
    final DateTime? date = appointment.date;

    return AppointmentCard(
      // A turn whose schedule was deleted is a real row the server returns.
      // Em dashes rather than a hidden card: the appointment is still the
      // patient's, and it still has a ticket number they may be asked for.
      weekday: date == null ? '—' : weekdayLabel(date),
      day: date == null ? '—' : dayLabel(date),
      month: date == null ? '' : monthLabel(date),
      specialty:
          appointment.speciality ?? appointment.serviceName ?? 'Consulta',
      doctor: appointment.doctorName ?? 'Por asignar',
      time: appointment.time == null
          ? 'Horario por confirmar'
          : '${appointment.time} / turno ${appointment.ticket}',
      location: appointment.locationName ?? 'Sede por confirmar',
      status: _cardStatus,
      // Only an UPCOMING turn can be cancelled — the same set the server
      // accepts on `PUT /{id}/cancelled` (anything but treated/cancelled).
      // Offering it on a past card would just collect a 400 the patient did
      // not cause.
      actions: appointment.isUpcoming
          ? <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    // Reported here, next to the button that failed — not as
                    // a snackbar that slides away before it is read. Same
                    // convention `_BookingPanel` uses for a failed booking.
                    if (cancelError != null)
                      Text(
                        cancelError!.message,
                        style: AppTypography.cap.copyWith(
                          color: AppColors.emergency,
                        ),
                      ),
                    AppButton(
                      label: 'Cancelar turno',
                      variant: AppButtonVariant.ghost,
                      isLoading: isCancelling,
                      onPressed: isCancelling
                          ? null
                          : () => _confirmCancel(context, appointment.id),
                    ),
                  ],
                ),
              ),
            ]
          : null,
    );
  }
}

/// Confirms before cancelling — the same one-tap gate `ProfileScreen` puts in
/// front of "cerrar sesion". A cancellation cannot be undone from the app, so
/// it earns the same pause a sign-out does.
Future<void> _confirmCancel(BuildContext context, int turnId) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancelar este turno?'),
      content: const Text(
        'Esta acción no se puede deshacer. Vas a perder el lugar reservado.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Volver',
            style: AppTypography.button.copyWith(color: AppColors.ink2),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Cancelar turno',
            style: AppTypography.button.copyWith(color: AppColors.emergency),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  context.read<AppointmentsBloc>().add(AppointmentCancelRequested(turnId));
}

/// Reserves the real geometry of two cards while the first load runs.
class _AppointmentsSkeleton extends StatelessWidget {
  const _AppointmentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.section,
      children: <Widget>[
        AppSkeleton.card(height: 132),
        AppSkeleton.card(height: 132),
      ],
    );
  }
}

/// A failed load, with the one action that helps.
///
/// Deliberately NOT [AppEmptyState] — see the screen's doc.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.lg,
        children: <Widget>[
          Text(message, style: AppTypography.body, textAlign: TextAlign.center),
          AppButton(
            label: 'Reintentar',
            variant: AppButtonVariant.ghost,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
