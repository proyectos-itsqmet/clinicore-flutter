import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constant/app_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/establishment.dart';
import '../blocs/booking/booking_bloc.dart';

/// The "Agendar" tab — a step-by-step wizard, one screen per step.
///
/// A direct behavioural port of `clinicore-angular`'s `BookingPage`: the same
/// four steps (Sede, Servicio y Doctor, Horario, Confirmado), the same
/// forward-only progression, the same "Volver" that can only go BACK, and the
/// same rule that choosing again at an earlier step clears everything chosen
/// after it. See [BookingBloc] for where each of those rules actually lives —
/// this file only renders [BookingState].
///
/// ## Why a wizard and not the web page's four-tab layout
///
/// The web page keeps all four steps in one component and shows a
/// numbered-tab header where later tabs are `[disabled]` until reachable.
/// That header assumes width a phone does not have: four tab labels plus
/// icons is either a wall of tiny text or four icons with no label at all.
/// One step per screen, with a single "Volver" line back to the previous
/// one, is what a checkout flow on a phone already does, and it needs no tab
/// strip to enforce forward-only progress — there is simply no widget on
/// screen that skips ahead.
///
/// ## The device's back button is part of the wizard
///
/// See [_BookingBackGuard]. The short version: this screen is the root of a
/// shell branch, so without that guard the hardware back button had nothing
/// to pop and left the app entirely — from step 3, with a sede, a service, a
/// doctor and a slot already chosen.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookingBloc>(
      create: (_) => sl<BookingBloc>()..add(const BookingStarted()),
      child: const _BookingView(),
    );
  }
}

class _BookingView extends StatelessWidget {
  const _BookingView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listenWhen: (BookingState previous, BookingState current) =>
          current.isSessionExpired && !previous.isSessionExpired,
      listener: (BuildContext context, BookingState state) {
        context.read<AuthBloc>().add(const AuthSessionExpired());
      },
      builder: (BuildContext context, BookingState state) {
        // The guard is OUTSIDE the scroll view rather than around one step:
        // it has to be registered with this route for as long as the wizard
        // is on screen, not only while a particular step is drawn.
        return _BookingBackGuard(
          state: state,
          // Step 1's search box is this feature's first raw `TextField` —
          // every other home screen only uses `AppButton`/`AppChip`/
          // `AppCard`, which wrap their OWN `Material` internally. In
          // production this screen sits inside `HomeScreen`'s `Scaffold`,
          // which already provides one; this `transparency` Material is what
          // makes the screen correct on its own too, with no visual change
          // either way.
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.pad,
                  right: AppSpacing.pad,
                  top: AppSpacing.sectionY * 0.5,
                  // With `extendBody` on the shell, this is the nav bar's
                  // height.
                  bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.section,
                  children: <Widget>[
                    _WizardHeader(state: state),
                    switch (state.step) {
                      BookingStep.establishment => _EstablishmentStep(
                        state: state,
                      ),
                      BookingStep.serviceAndDoctor => _ServiceAndDoctorStep(
                        state: state,
                      ),
                      BookingStep.schedule => _ScheduleStep(state: state),
                      BookingStep.confirmed => _ConfirmedStep(state: state),
                    },
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Makes the device's back button walk the wizard BACKWARDS instead of
/// leaving it.
///
/// ## The bug this fixes
///
/// "Agendar" is the root of its own shell branch, so its navigator has
/// exactly one route and nothing to pop. `go_router` asks the active branch
/// first (`GoRouterDelegate._findCurrentNavigators`), gets "I cannot pop",
/// falls through to the root — which also has one route — and the gesture
/// reaches the platform, which backgrounds the app. From step 3 that means a
/// patient who had already chosen a sede, a service, a doctor and a slot lost
/// all four to the gesture they use most.
///
/// ## Why no "vas a perder el progreso" dialog
///
/// Because with this in place there is no progress to lose. A confirmation
/// dialog is the right tool when the action is irreversible and the user
/// cannot see what it costs — that is why cancelling a turn has one. Back
/// here is neither: it moves one step, the move is visible, and the step is
/// one tap away again. A dialog on every back would put a modal in front of
/// the most-used gesture on the phone to protect against something that no
/// longer happens.
///
/// ## What each step does
///
/// | step                | back                                            |
/// |---------------------|-------------------------------------------------|
/// | 1 Sede              | leaves — nothing chosen, nothing to protect      |
/// | 2 Servicio y doctor | step 1                                          |
/// | 3 Horario           | step 2                                          |
/// | 3 Horario, booking  | nothing: the request may already have landed     |
/// | 4 Confirmado        | starts a fresh booking, like "Agendar otro turno"|
///
/// Step 4 is the one that is not obvious. The turn is already booked and the
/// ticket is on screen, so there is no step behind it to return to — but
/// dropping the patient out of the app one gesture after they booked reads as
/// a crash, and it is the moment they are least sure the booking worked.
/// Resetting is exactly what the button under the ticket already does, and it
/// leaves the branch on step 1 instead of parked on a stale ticket. A second
/// back from there leaves normally.
class _BookingBackGuard extends StatelessWidget {
  const _BookingBackGuard({required this.state, required this.child});

  final BookingState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Blocked outright while the booking request is in flight — the same rule
    // `ResetPasswordScreen` applies to a password already being written. The
    // server may have created the turn; unwinding the wizard underneath that
    // would leave the patient with a turn and no ticket.
    final bool booking = state.status == BookingStatus.booking;
    final BookingStep? previous = state.previousStep;
    final bool handled =
        booking || previous != null || state.step == BookingStep.confirmed;

    return PopScope(
      // `false` makes the route report `doNotPop`, which is what turns the
      // gesture into a callback instead of an exit. `true` lets it bubble the
      // way it always did — which on step 1 is correct.
      canPop: !handled,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || booking) return;

        final BookingBloc bloc = context.read<BookingBloc>();
        if (previous != null) {
          bloc.add(BookingStepBackRequested(previous));
          return;
        }
        bloc.add(const BookingReset());
      },
      child: child,
    );
  }
}

/// The kicker + title every step opens with, plus a "Volver" back into the
/// previous one — absent on step 1 (nothing behind it) and step 4 (the only
/// way out of a ticket is "Agendar otro turno", not a step back).
///
/// The target comes from [BookingState.previousStep] rather than from a table
/// of its own, so this link and the device's back button can never drift into
/// disagreeing about what "back" means — see [_BookingBackGuard].
class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.state});

  final BookingState state;

  static const Map<BookingStep, String> _titles = <BookingStep, String>{
    BookingStep.establishment: 'Elige tu sede',
    BookingStep.serviceAndDoctor: 'Servicio y doctor',
    BookingStep.schedule: 'Elige tu horario',
    BookingStep.confirmed: 'Turno confirmado',
  };

  @override
  Widget build(BuildContext context) {
    final BookingStep? back = state.previousStep;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: <Widget>[
        AppSectionHeading(
          kicker: 'Paso ${state.step.index + 1} de 4',
          title: _titles[state.step]!,
        ),
        if (back != null)
          GestureDetector(
            onTap: () =>
                context.read<BookingBloc>().add(BookingStepBackRequested(back)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.xxs,
              children: <Widget>[
                const Icon(
                  AppIcons.chevronLeft,
                  size: 12,
                  color: AppColors.blueText,
                ),
                Text(
                  'Volver',
                  style: AppTypography.cap.copyWith(
                    color: AppColors.blueText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Step 1: pick a sede, with a text search over the loaded list.
class _EstablishmentStep extends StatelessWidget {
  const _EstablishmentStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    if (state.isFirstLoad) return const AppSkeleton.card(height: 280);

    if (state.status == BookingStatus.failure) {
      return _StepError(
        message: state.failure?.message ?? 'No pudimos cargar las sedes.',
        onRetry: () =>
            context.read<BookingBloc>().add(const BookingStarted()),
      );
    }

    final List<Establishment> visible = state.visibleEstablishments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        AppTextField(
          label: 'Buscar sede',
          hint: 'Nombre de la sede',
          onChanged: (String value) => context.read<BookingBloc>().add(
            BookingEstablishmentSearchChanged(value),
          ),
        ),
        if (visible.isEmpty)
          const AppEmptyState(
            icon: AppIcons.location,
            title: 'Sin resultados',
            message: 'No encontramos ninguna sede con ese nombre.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: <Widget>[
              for (final Establishment establishment in visible)
                AppListRow(
                  label: establishment.name,
                  supporting: establishment.address,
                  icon: AppIcons.location,
                  onTap: () => context.read<BookingBloc>().add(
                    BookingEstablishmentSelected(establishment),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Step 2: pick a service and, optionally, a doctor within it.
class _ServiceAndDoctorStep extends StatelessWidget {
  const _ServiceAndDoctorStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == BookingStatus.loadingServices) {
      return const AppSkeleton.card(height: 280);
    }

    if (state.status == BookingStatus.failure) {
      return _StepError(
        message: state.failure?.message ?? 'No pudimos cargar los servicios.',
        onRetry: () {
          final Establishment? establishment = state.establishment;
          if (establishment == null) return;
          context.read<BookingBloc>().add(
            BookingEstablishmentSelected(establishment),
          );
        },
      );
    }

    if (state.hasNoServices) {
      return const AppEmptyState(
        icon: AppIcons.specialty,
        title: 'Sin servicios',
        message: 'Esta sede todavia no tiene servicios habilitados.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        for (final ServiceWithDoctors offer in state.servicesWithDoctors)
          _ServiceCard(offer: offer),
      ],
    );
  }
}

/// One service: its price, the doctors named for it, and "cualquier doctor
/// disponible" for when the patient does not care who they see.
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.offer});

  final ServiceWithDoctors offer;

  /// `USD 30`, matching the rest of the app. No decimals: every price in the
  /// catalogue is whole dollars.
  String _money(double value) => 'USD ${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = context.read<BookingBloc>();
    final BookingService service = offer.service;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  service.name,
                  style: AppTypography.h3.copyWith(fontSize: 16),
                ),
              ),
              Text(
                _money(service.hasDiscount ? service.finalPrice : service.price),
                style: AppTypography.meta.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          for (final BookingDoctor doctor in offer.doctors)
            AppListRow(
              label: doctor.fullName,
              supporting: doctor.speciality,
              icon: AppIcons.specialty,
              onTap: () => bloc.add(
                BookingServiceAndDoctorSelected(service, doctor),
              ),
            ),
          AppButton(
            // Names the SERVICE, not just "cualquier doctor": with more
            // than one service card on screen, an unqualified label would
            // be the one tappable string a test (or a patient scanning the
            // screen) cannot tell apart from its sibling.
            label: 'Cualquier doctor para ${service.name}',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: () =>
                bloc.add(BookingServiceAndDoctorSelected(service, null)),
          ),
        ],
      ),
    );
  }
}

/// Step 3: pick a FREE slot, with a quick date filter above the list.
class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = context.read<BookingBloc>();
    final bool loading = state.status == BookingStatus.loadingSchedules;
    final bool booking = state.status == BookingStatus.booking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.lg,
      children: <Widget>[
        _SelectionRecap(state: state),
        _DateFilterBar(current: state.dateFilter),

        // A booking failure is reported HERE, next to the list it happened
        // on — never a snackbar that slides away before it is read, and
        // never a reason to lose the schedule, the doctor or the service
        // already chosen.
        if (state.status == BookingStatus.failure && state.failure != null)
          Text(
            state.failure!.message,
            style: AppTypography.cap.copyWith(color: AppColors.emergency),
          ),

        if (loading)
          const AppSkeleton.card(height: 160)
        else if (state.hasNoSchedules)
          const AppEmptyState(
            icon: AppIcons.calendar,
            title: 'Sin horarios libres',
            message:
                'No hay cupos disponibles para estos filtros. Proba otra '
                'fecha o otro servicio.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final BookingSlot slot in state.schedules)
                AppChip(
                  // With no date filter, a chip can be any upcoming day, so
                  // the date has to be on the label — otherwise two 09:00
                  // chips a week apart would read as one duplicated slot.
                  label: state.dateFilter == null
                      ? '${shortDate(slot.date)} ${slot.time}'
                      : slot.time,
                  selected: state.schedule == slot,
                  expand: true,
                  onTap: () => bloc.add(BookingScheduleSelected(slot)),
                ),
            ],
          ),

        if (state.schedule != null)
          AppButton(
            label: booking ? 'Reservando...' : 'Confirmar turno',
            fullWidth: true,
            onPressed: !booking
                ? () => bloc.add(const BookingConfirmed())
                : null,
          ),
      ],
    );
  }
}

/// Sede / Servicio / Doctor, read back to the patient above the slot list —
/// step 3 is the first screen where all three are decided at once, so it is
/// the one place worth confirming them before asking for a fourth.
class _SelectionRecap extends StatelessWidget {
  const _SelectionRecap({required this.state});

  final BookingState state;

  static const String _anyDoctor = 'Cualquier doctor';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: AppCardTone.field,
      padding: const EdgeInsets.all(AppSpacing.cardPadSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xs,
        children: <Widget>[
          AppSummaryRow(
            label: 'Sede',
            value: state.establishment?.name ?? '--',
          ),
          AppSummaryRow(label: 'Servicio', value: state.service?.name ?? '--'),
          AppSummaryRow(
            label: 'Doctor',
            value: state.doctor?.fullName ?? _anyDoctor,
          ),
        ],
      ),
    );
  }
}

/// "Todos" / "Hoy" / "Manana" / a picked day — mirrors
/// `setTodayFilter`/`setTomorrowFilter`/`clearDateFilter`/`onDateChange`.
/// "Hoy" and "Manana" are resolved to a concrete midnight [DateTime] HERE,
/// in the widget: [BookingBloc] takes whatever [DateTime] it is given and
/// never calls `DateTime.now()` itself.
class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({required this.current});

  final DateTime? current;

  static DateTime _midnight(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = context.read<BookingBloc>();
    final DateTime today = _midnight(DateTime.now());
    final DateTime tomorrow = today.add(const Duration(days: 1));

    return Row(
      spacing: AppSpacing.sm,
      children: <Widget>[
        Expanded(
          child: AppChip(
            label: 'Todos',
            selected: current == null,
            onTap: () =>
                bloc.add(const BookingDateFilterChanged(null)),
          ),
        ),
        Expanded(
          child: AppChip(
            label: 'Hoy',
            selected: _isSameDay(current, today),
            onTap: () => bloc.add(BookingDateFilterChanged(today)),
          ),
        ),
        Expanded(
          child: AppChip(
            label: 'Manana',
            selected: _isSameDay(current, tomorrow),
            onTap: () => bloc.add(BookingDateFilterChanged(tomorrow)),
          ),
        ),
        IconButton(
          tooltip: 'Elegir fecha',
          onPressed: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: current ?? today,
              firstDate: today,
              lastDate: today.add(const Duration(days: 180)),
            );
            if (picked == null) return;
            bloc.add(BookingDateFilterChanged(_midnight(picked)));
          },
          icon: const Icon(AppIcons.calendar, size: 20),
          color: AppColors.ink2,
        ),
      ],
    );
  }
}

/// Step 4: the confirmed ticket.
class _ConfirmedStep extends StatelessWidget {
  const _ConfirmedStep({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final Appointment? appointment = state.booked;
    // Only reachable once the server actually confirmed — see
    // `BookingBloc._onConfirmed`, which is the only place `step` becomes
    // `confirmed`, always alongside `booked`.
    if (appointment == null) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadLg),
      crossAxisAlignment: CrossAxisAlignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: AppSpacing.lg,
        children: <Widget>[
          const AppTick(),
          Text('Turno reservado', style: AppTypography.h3),
          Text(
            'Numero de turno: ${appointment.ticket}',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
          if (appointment.date != null)
            Text(
              '${shortDate(appointment.date!)}'
              '${appointment.time == null ? '' : ' - ${appointment.time}'}',
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
          AppButton(
            label: 'Agendar otro turno',
            fullWidth: true,
            onPressed: () =>
                context.read<BookingBloc>().add(const BookingReset()),
          ),
        ],
      ),
    );
  }
}

/// A step that failed to load, with the way back in.
class _StepError extends StatelessWidget {
  const _StepError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.warning,
      title: 'Algo salio mal',
      message: message,
      actionLabel: 'Reintentar',
      onAction: onRetry,
    );
  }
}
