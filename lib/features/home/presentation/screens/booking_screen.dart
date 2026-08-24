import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/helpers/date_labels.dart';
import '../../../../shared/ui/atoms/atoms.dart';
import '../../../../shared/ui/molecules/molecules.dart';
import '../../../auth/presentation/blocs/auth/auth_bloc.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/availability.dart';
import '../blocs/booking/booking_bloc.dart';

/// The "Agendar" tab — a direct port of the booking widget from
/// `design/Mobile.dc.html`'s AGENDA DEMO section, now on real availability.
///
/// Three numbered steps (doctor, day, time), then a summary panel that shows
/// the price before the user commits, then one primary action. The order is the
/// product's whole argument: "Elige, mira el valor y confirma."
///
/// Everything visual comes from the board — the 22px gap between step groups,
/// the 11px step kickers, the 7px grid gaps, the four-column day and time
/// grids, and the confirmed state REPLACING the button rather than sitting next
/// to it.
///
/// ## What changed when the data became real
///
/// * **The type switch is services, not three fixed labels.** The board draws
///   "Consulta / Control / Telemedicina"; the server has a `services` table,
///   and those are whatever the clinic configured.
/// * **Days come from the slots.** Only days with at least one FREE slot get a
///   chip: a day that opens onto a grid of struck-through hours is a tap that
///   could not lead anywhere.
/// * **"Con tu plan" is gone.** It needs `insurers` / `coverage_plans` /
///   `patient_coverage`, and none of those tables exist. What does exist is
///   `services.discount`, a flat amount off for everyone — so the panel shows
///   the real price, and a struck-through original only when there is a real
///   discount. Inventing an insurer price is inventing a number a patient might
///   budget around.
/// * **The green "Reservado" bar waits for the server.** The sample version
///   flipped a local flag on tap. A slot can be taken between the grid loading
///   and the tap landing, and in a clinic that happens on a Tuesday morning.
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
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.pad,
          right: AppSpacing.pad,
          top: AppSpacing.sectionY * 0.5,
          // With `extendBody` on the shell, this is the nav bar's height.
          bottom: AppSpacing.sectionY * 0.5 + context.bottomSafeInset,
        ),
        child: BlocConsumer<BookingBloc, BookingState>(
          listenWhen: (BookingState previous, BookingState current) =>
              current.isSessionExpired && !previous.isSessionExpired,
          listener: (BuildContext context, BookingState state) {
            context.read<AuthBloc>().add(const AuthSessionExpired());
          },
          builder: (BuildContext context, BookingState state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.section,
              children: <Widget>[
                const AppSectionHeading(
                  kicker: 'Agenda en linea',
                  title: 'Elige, mira el valor y confirma.',
                ),

                if (state.isFirstLoad)
                  const AppSkeleton.card(height: 460)
                else if (state.services.isEmpty || state.doctors.isEmpty)
                  _CannotStart(state: state)
                else ...<Widget>[
                  AppSegmented(
                    options: state.services
                        .map((BookingService s) => s.name)
                        .toList(),
                    selectedIndex: state.service == null
                        ? 0
                        : state.services.indexOf(state.service!),
                    onChanged: (int index) => context.read<BookingBloc>().add(
                      BookingServiceSelected(state.services[index]),
                    ),
                  ),

                  _BookingPanel(state: state),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The board's white panel: `border-radius: 26px`, a `line` hairline,
/// `--shadow-lift-1`, 20px of padding and 22px between step groups.
class _BookingPanel extends StatelessWidget {
  const _BookingPanel({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = context.read<BookingBloc>();
    final List<DateTime> days = state.bookableDays;
    final List<BookingSlot> slots = state.slotsForDay;
    final bool loadingSlots = state.status == BookingStatus.loadingSlots;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.lift1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 22,
        children: <Widget>[
          _Step(
            label: '1 / Medico',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final BookingDoctor doctor in state.doctors)
                  AppChip(
                    label: doctor.chipLabel,
                    selected: state.doctor == doctor,
                    expand: true,
                    onTap: () => bloc.add(BookingDoctorSelected(doctor)),
                  ),
              ],
            ),
          ),

          _Step(
            label: '2 / Dia',
            // Three different empty grids that mean three different things.
            // Showing the same blank for all of them is how a patient concludes
            // there are no appointments when they simply have not picked a
            // doctor yet.
            note: !state.hasPair
                ? 'Elegi un medico para ver los dias disponibles.'
                : state.hasNoAvailability
                ? 'Este medico no tiene cupos libres en los proximos 60 dias.'
                : null,
            child: loadingSlots
                ? const AppSkeleton.card(height: 64)
                : _Grid(
                    children: <Widget>[
                      for (final DateTime day in days)
                        AppDayChip(
                          weekday: weekdayLabel(day),
                          day: dayLabel(day),
                          selected: state.day == day,
                          onTap: () => bloc.add(BookingDaySelected(day)),
                        ),
                    ],
                  ),
          ),

          _Step(
            label: '3 / Hora',
            note: slots.isEmpty
                ? null
                : 'Los cupos tachados ya estan ocupados.',
            child: loadingSlots
                ? const AppSkeleton.card(height: 100)
                : _Grid(
                    children: <Widget>[
                      for (final BookingSlot slot in slots)
                        AppChip(
                          label: slot.time,
                          selected: state.slot == slot,
                          disabled: !slot.isFree,
                          onTap: () => bloc.add(BookingSlotSelected(slot)),
                        ),
                    ],
                  ),
          ),

          _SummaryPanel(state: state),
        ],
      ),
    );
  }
}

/// One numbered step: an 11px kicker, its control, and an optional note.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.child, this.note});

  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: <Widget>[
        AppKicker(text: label, size: 11),
        child,
        if (note != null) Text(note!, style: AppTypography.cap),
      ],
    );
  }
}

/// The board's `grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 7px`.
///
/// A [Wrap] would let a row of three sit at its natural width and break the
/// column alignment between the day grid and the time grid, so this stays a
/// real four-column grid.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  static const int _columns = 4;
  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < children.length; i += _columns) {
      final int end = (i + _columns).clamp(0, children.length);
      final List<Widget> cells = children.sublist(i, end);
      rows.add(
        Row(
          spacing: _gap,
          children: <Widget>[
            for (final Widget cell in cells) Expanded(child: cell),
            // Keeps a short final row's cells the same width as the rest,
            // instead of stretching them across the whole panel.
            for (int j = cells.length; j < _columns; j++)
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
    }

    return Column(spacing: _gap, children: rows);
  }
}

/// The nested summary: the field-toned panel inside the white one.
///
/// It uses [AppRadii.signatureSm] (`20px 20px 8px 20px`), which is the
/// signature corner at panel scale — the board nests the shape inside itself
/// rather than switching to a plain rectangle.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state});

  final BookingState state;

  static const String _blank = '--';

  @override
  Widget build(BuildContext context) {
    final BookingService? service = state.service;
    final bool booked = state.status == BookingStatus.booked;
    final bool booking = state.status == BookingStatus.booking;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPad),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: AppRadii.signatureSm,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xl,
        children: <Widget>[
          Column(
            spacing: AppSpacing.md,
            children: <Widget>[
              AppSummaryRow(
                label: 'Medico',
                value: state.doctor?.fullName ?? _blank,
              ),
              AppSummaryRow(
                label: 'Dia',
                value: state.day == null
                    ? _blank
                    : '${weekdayLabel(state.day!)} ${dayLabel(state.day!)} '
                          '${monthLabel(state.day!)}',
              ),
              AppSummaryRow(
                label: 'Hora',
                value: state.slot?.time ?? _blank,
                valueColor: state.isComplete ? AppColors.blueText : null,
              ),
            ],
          ),

          const AppHairline(),

          if (service != null) _PriceRows(service: service),

          // A booking that failed is reported here, next to the button that
          // failed — not as a snackbar that slides away before it is read.
          if (state.status == BookingStatus.failure && state.failure != null)
            Text(
              state.failure!.message,
              style: AppTypography.cap.copyWith(color: AppColors.emergency),
            ),

          if (booked && state.booked != null)
            _ConfirmedBar(appointment: state.booked!)
          else
            AppButton(
              label: booking ? 'Reservando...' : 'Confirmar cita',
              fullWidth: true,
              // Disabled until all three steps are answered — the summary
              // above already shows exactly which one is still `--`.
              onPressed: state.isComplete && !state.isBusy
                  ? () => context.read<BookingBloc>().add(
                      const BookingConfirmed(),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// The price, and only the prices that exist.
///
/// The board's struck-through "list price" over a lower "Con tu plan" needs
/// coverage tables the server does not have. `services.discount` does exist —
/// a flat amount off for everyone — so the struck-through row appears ONLY when
/// there is a real discount, and it is labelled as one.
class _PriceRows extends StatelessWidget {
  const _PriceRows({required this.service});

  final BookingService service;

  /// `USD 30`, matching the board. No decimals: every price in the catalogue is
  /// whole dollars, and `USD 30.00` is two characters of noise in a summary row.
  String _money(double value) => 'USD ${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: <Widget>[
        if (service.hasDiscount) ...<Widget>[
          AppSummaryRow(
            label: service.name,
            value: _money(service.price),
            strikethrough: true,
          ),
          AppSummaryRow(
            label: 'Con descuento',
            value: _money(service.finalPrice),
            emphasis: AppFigure(
              value: _money(service.finalPrice),
              size: 24,
              color: AppColors.ok,
            ),
          ),
        ] else
          AppSummaryRow(
            label: service.name,
            value: _money(service.price),
            emphasis: AppFigure(value: _money(service.price), size: 24),
          ),

        Text(
          'Valor referencial. La cobertura de tu seguro se aplica en '
          'recepcion.',
          style: AppTypography.cap,
        ),
      ],
    );
  }
}

/// The confirmed state: the board's green pill, replacing the button.
///
/// It replaces rather than joins the CTA on purpose. Two controls where there
/// was one reads as "did it work?"; one control that changed reads as "done".
///
/// It shows the TICKET number the server assigned, not just the hour. That
/// number is what gets called in the waiting room, so it is the one thing worth
/// remembering out of this whole flow.
class _ConfirmedBar extends StatelessWidget {
  const _ConfirmedBar({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPad),
      decoration: const BoxDecoration(
        color: AppColors.ok,
        borderRadius: AppRadii.pillAll,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpacing.md,
        children: <Widget>[
          const AppTick(),
          Text(
            'Reservado / turno ${appointment.ticket}',
            style: AppTypography.pill.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The flow cannot start: the clinic has no doctors or no services configured.
///
/// Says WHICH, because "no hay turnos" sends the patient to phone reception
/// about the wrong thing.
class _CannotStart extends StatelessWidget {
  const _CannotStart({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final String message = state.status == BookingStatus.failure
        ? state.failure?.message ?? 'No pudimos cargar la agenda.'
        : state.services.isEmpty
        ? 'La clinica todavia no publico los tipos de consulta. '
              'Comunicate con recepcion para agendar.'
        : 'La clinica todavia no publico su cuerpo medico en la app. '
              'Comunicate con recepcion para agendar.';

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
            onPressed: () =>
                context.read<BookingBloc>().add(const BookingStarted()),
          ),
        ],
      ),
    );
  }
}
