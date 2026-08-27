import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/appointment.dart';
import '../../../domain/entities/availability.dart';
import '../../../domain/entities/establishment.dart';
import '../../../domain/usecases/booking_usecases.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Drives the four steps of "Agendar" — Sede, Servicio y Doctor, Horario,
/// Confirmado — and the booking itself.
///
/// A direct port of `clinicore-angular`'s `BookingPage`, restructured as a
/// wizard instead of one page with four conditional sections: mobile has no
/// room to show a stepper AND a full step's content at once, so each step
/// gets the whole screen and a "Volver" back into the previous one.
///
/// ## Selections cascade downward, and only downward
///
/// Picking a DIFFERENT sede invalidates the service, the doctor and the
/// schedule: those belonged to the previous sede and booking one would book
/// the wrong appointment. Picking a different service (with or without a
/// doctor) invalidates only the schedule. That is what `copyWith`'s
/// `clearService` / `clearDoctor` / `clearSchedule` flags exist for — a
/// nullable parameter cannot express "set this back to nothing".
///
/// Going BACK a step, by itself, clears nothing — exactly like `goToStep`.
/// Only a fresh selection at an earlier step invalidates what came after it.
///
/// ## The doctor filter reaches the REQUEST
///
/// `GetFreeSchedulesParams.doctorId` is forwarded to
/// `BookingRepository.getFreeSchedules` untouched, all the way down to a
/// `doctorId` query parameter on `/api/schedules`. Nothing in this bloc (or
/// the repository below it) filters the RESULT by doctor — that is
/// `clinicore-angular`'s `loadAvailableSchedules` bug, where a doctor's
/// slots past whatever page the request asked for are invisible.
///
/// ## The confirmation is the SERVER's, not the tap's
///
/// [BookingStatus.booked] is emitted from the response, and carries the
/// created [Appointment] so the screen can show the real ticket number. A
/// slot can be taken between the grid loading and the tap landing, and a
/// failed booking keeps every selection and stays on step 3 — see
/// [_onConfirmed] — so the patient is never sent back to pick everything
/// again over a slot someone else took first.
///
/// ## Step 3 is always ONE day, and never a day already spent
///
/// Two rules that used to be missing, and that cost the same patient twice:
///
/// 1. **There is no "todos los dias".** The date filter used to accept null,
///    which sent no `date` parameter at all — so the server answered with
///    every free slot it had, across every future day, capped only by the
///    data source's 1000-row ceiling. One service could put a hundred chips
///    on screen. Step 3 now always asks about exactly one day.
/// 2. **Past slots never reach the list.** Nothing on either side used to
///    compare a slot against the clock: the server's schedule query filters
///    date, sede, doctor, service and status, and none of those say "and it
///    has not happened yet". At 11:00 the 08:00 slot was still `STATUS_FREE`
///    — nobody had booked it — so it was drawn, and tapping it booked a turn
///    for an hour that was gone. `TurnService.requireUpcoming` is what makes
///    that impossible; [_fetchSchedules] is what stops the app from offering
///    it in the first place.
///
/// Entering step 3 resolves the day itself, via [_loadDefaultDay]: today, or
/// tomorrow when today has nothing left. Landing on an empty "Hoy" at 19:00
/// reads as "this service has no availability", which is a different and
/// wrong answer.
///
/// ## The clock is injected
///
/// [clock] defaults to `DateTime.now`, and every "today" in this bloc goes
/// through it. That is what lets the tests pin the hour and assert the
/// boundary exactly, instead of building fixtures around whenever the suite
/// happens to run.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({
    required this.getEstablishments,
    required this.getServicesWithDoctors,
    required this.getFreeSchedules,
    required this.bookSlot,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now,
       super(const BookingState.initial()) {
    on<BookingStarted>(_onStarted);
    on<BookingEstablishmentSearchChanged>(_onSearchChanged);
    on<BookingEstablishmentSelected>(_onEstablishmentSelected);
    on<BookingServiceAndDoctorSelected>(_onServiceAndDoctorSelected);
    on<BookingDateFilterChanged>(_onDateFilterChanged);
    on<BookingScheduleSelected>(_onScheduleSelected);
    on<BookingConfirmed>(_onConfirmed);
    on<BookingStepBackRequested>(_onStepBackRequested);
    on<BookingReset>(_onReset);
  }

  final GetEstablishments getEstablishments;
  final GetServicesWithDoctors getServicesWithDoctors;
  final GetFreeSchedules getFreeSchedules;
  final BookSlot bookSlot;

  /// This bloc's only source of "now". Public because the schedule step's
  /// date filter has to mark the same day this bloc considers today — two
  /// clocks would let the bar highlight "Hoy" for a list fetched for
  /// yesterday, on either side of midnight.
  final DateTime Function() now;

  /// Local midnight of the current day.
  DateTime get _today {
    final DateTime instant = now();
    return DateTime(instant.year, instant.month, instant.day);
  }

  /// Local midnight of the next day.
  ///
  /// Built by incrementing the day FIELD rather than adding 24 hours —
  /// `DateTime` normalises an overflowing day into the next month, and a day
  /// that is not 24 hours long (a DST change anywhere the clinic might open)
  /// would leave `.add(Duration(days: 1))` at 23:00 of the same date.
  DateTime get _tomorrow {
    final DateTime today = _today;
    return DateTime(today.year, today.month, today.day + 1);
  }

  Future<void> _onStarted(
    BookingStarted event,
    Emitter<BookingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BookingStatus.loadingEstablishments,
        clearFailure: true,
      ),
    );

    final result = await getEstablishments(const NoParams());

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: BookingStatus.failure, failure: failure),
        (List<Establishment> establishments) => state.copyWith(
          status: BookingStatus.ready,
          establishments: establishments,
          clearFailure: true,
        ),
      ),
    );
  }

  void _onSearchChanged(
    BookingEstablishmentSearchChanged event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(establishmentSearch: event.query));
  }

  Future<void> _onEstablishmentSelected(
    BookingEstablishmentSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(
      state.copyWith(
        step: BookingStep.serviceAndDoctor,
        establishment: event.establishment,
        status: BookingStatus.loadingServices,
        servicesWithDoctors: const <ServiceWithDoctors>[],
        clearService: true,
        clearDoctor: true,
        clearSchedule: true,
        clearBooked: true,
        clearFailure: true,
      ),
    );

    final result = await getServicesWithDoctors(event.establishment.id);

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: BookingStatus.failure, failure: failure),
        (List<ServiceWithDoctors> services) => state.copyWith(
          status: BookingStatus.ready,
          servicesWithDoctors: services,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onServiceAndDoctorSelected(
    BookingServiceAndDoctorSelected event,
    Emitter<BookingState> emit,
  ) async {
    emit(
      state.copyWith(
        step: BookingStep.schedule,
        service: event.service,
        doctor: event.doctor,
        clearDoctor: event.doctor == null,
        status: BookingStatus.loadingSchedules,
        schedules: const <BookingSlot>[],
        // Marked BEFORE the request so the bar highlights "Hoy" while it
        // loads. [_loadDefaultDay] moves it to tomorrow only if today comes
        // back with nothing.
        dateFilter: _today,
        clearSchedule: true,
        clearBooked: true,
        clearFailure: true,
      ),
    );

    await _loadDefaultDay(emit);
  }

  Future<void> _onDateFilterChanged(
    BookingDateFilterChanged event,
    Emitter<BookingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BookingStatus.loadingSchedules,
        dateFilter: event.date,
        clearSchedule: true,
        clearBooked: true,
        clearFailure: true,
      ),
    );

    await _loadSchedulesFor(event.date, emit);
  }

  /// Picks the day step 3 opens on: today, or tomorrow when today is spent.
  ///
  /// The retry deliberately does NOT emit the empty today in between. Going
  /// `loading -> ready(empty) -> loading -> ready(tomorrow)` would flash "Sin
  /// horarios libres" for one frame on a screen that is about to show a full
  /// list, and a message that contradicts itself is worse than a slightly
  /// longer spinner.
  ///
  /// A FAILED request is not retried against tomorrow either: a failure means
  /// we do not know whether today has slots, and quietly moving the day would
  /// replace a real error with an answer about a day nobody asked for.
  Future<void> _loadDefaultDay(Emitter<BookingState> emit) async {
    final DateTime today = _today;
    final Either<Failure, List<BookingSlot>>? result = await _fetchSchedules(
      today,
    );
    if (result == null) return;

    final bool todayIsSpent = result.fold(
      (Failure _) => false,
      (List<BookingSlot> slots) => slots.isEmpty,
    );

    if (todayIsSpent) {
      await _loadSchedulesFor(_tomorrow, emit);
      return;
    }

    emit(_scheduleStateFrom(result, today));
  }

  /// Loads step 3 for exactly [day] and reports whatever comes back.
  Future<void> _loadSchedulesFor(DateTime day, Emitter<BookingState> emit) async {
    final Either<Failure, List<BookingSlot>>? result = await _fetchSchedules(
      day,
    );
    if (result == null) return;

    emit(_scheduleStateFrom(result, day));
  }

  /// Asks for [day]'s free slots and drops the ones that have already begun.
  ///
  /// Null when there is nothing to ask about yet — no service or no sede
  /// chosen — which is not a failure and must not be reported as one.
  ///
  /// ## Why the filter lives here and not in the widget
  ///
  /// Because [BookingState.hasNoSchedules] is computed from
  /// [BookingState.schedules]. A widget-side filter would leave the state
  /// saying "nine slots" while the screen drew none, and the "Sin horarios
  /// libres" message — the one thing that tells a patient to try another day
  /// — would never appear on precisely the day it is needed: one whose slots
  /// have all passed.
  ///
  /// The clock is read AFTER the round trip, not before it: on a slow
  /// connection the answer is judged against the moment it arrives, which is
  /// the moment the patient is looking at it.
  Future<Either<Failure, List<BookingSlot>>?> _fetchSchedules(
    DateTime day,
  ) async {
    final BookingService? service = state.service;
    final Establishment? establishment = state.establishment;
    if (service == null || establishment == null) return null;

    final Either<Failure, List<BookingSlot>> result = await getFreeSchedules(
      GetFreeSchedulesParams(
        establishmentId: establishment.id,
        serviceId: service.id,
        doctorId: state.doctor?.uuid,
        date: day,
      ),
    );

    final DateTime cutoff = now();
    return result.map(
      (List<BookingSlot> slots) =>
          slots.where((BookingSlot slot) => slot.isUpcomingAt(cutoff)).toList(),
    );
  }

  /// The state a finished schedule request produces, success or failure.
  ///
  /// [day] is recorded either way: a failed load still has to leave its chip
  /// marked, or the bar shows no selected day and "Reintentar" has nothing to
  /// retry against.
  BookingState _scheduleStateFrom(
    Either<Failure, List<BookingSlot>> result,
    DateTime day,
  ) {
    return result.fold(
      (Failure failure) => state.copyWith(
        status: BookingStatus.failure,
        failure: failure,
        dateFilter: day,
      ),
      (List<BookingSlot> slots) => state.copyWith(
        status: BookingStatus.ready,
        dateFilter: day,
        schedules: slots,
        clearFailure: true,
      ),
    );
  }

  void _onScheduleSelected(
    BookingScheduleSelected event,
    Emitter<BookingState> emit,
  ) {
    emit(state.copyWith(schedule: event.schedule, clearBooked: true));
  }

  Future<void> _onConfirmed(
    BookingConfirmed event,
    Emitter<BookingState> emit,
  ) async {
    final BookingSlot? schedule = state.schedule;
    if (schedule == null) return;

    emit(state.copyWith(status: BookingStatus.booking, clearFailure: true));

    final result = await bookSlot(schedule.scheduleId);

    emit(
      result.fold(
        // A failed booking stays on step 3, with the sede, the service, the
        // doctor and the schedule all still set — the patient does not lose
        // their place because a slot was taken a second before they tapped.
        (Failure failure) =>
            state.copyWith(status: BookingStatus.failure, failure: failure),
        (Appointment appointment) => state.copyWith(
          step: BookingStep.confirmed,
          status: BookingStatus.booked,
          booked: appointment,
          clearFailure: true,
        ),
      ),
    );
  }

  void _onStepBackRequested(
    BookingStepBackRequested event,
    Emitter<BookingState> emit,
  ) {
    // Mirrors `goToStep`: silently ignored when the target is not strictly
    // BEHIND the current step. The web page enforces the same rule with
    // `[disabled]` on its tabs; here it is enforced where a tap cannot route
    // around it.
    if (!state.canGoBackTo(event.step)) return;
    emit(state.copyWith(step: event.step, clearFailure: true));
  }

  void _onReset(BookingReset event, Emitter<BookingState> emit) {
    // Built from a fresh `BookingState.initial()`, not from `state.copyWith`:
    // every selection needs to go back to null, and `copyWith` has no flag
    // for "clear everything". The one thing worth keeping is the sede list —
    // it has not changed, so re-fetching it would just be latency.
    emit(
      const BookingState.initial().copyWith(
        status: BookingStatus.ready,
        establishments: state.establishments,
      ),
    );
  }
}
