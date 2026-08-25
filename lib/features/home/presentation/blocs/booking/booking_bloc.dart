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
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({
    required this.getEstablishments,
    required this.getServicesWithDoctors,
    required this.getFreeSchedules,
    required this.bookSlot,
  }) : super(const BookingState.initial()) {
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
        clearSchedule: true,
        clearBooked: true,
        clearFailure: true,
      ),
    );

    await _loadSchedules(emit);
  }

  Future<void> _onDateFilterChanged(
    BookingDateFilterChanged event,
    Emitter<BookingState> emit,
  ) async {
    emit(
      state.copyWith(
        status: BookingStatus.loadingSchedules,
        dateFilter: event.date,
        clearDateFilter: event.date == null,
        clearSchedule: true,
        clearBooked: true,
        clearFailure: true,
      ),
    );

    await _loadSchedules(emit);
  }

  /// Loads step 3 for the CURRENT service (+ establishment, + optional
  /// doctor and date). Shared by both events that can change what step 3
  /// needs to ask for.
  Future<void> _loadSchedules(Emitter<BookingState> emit) async {
    final BookingService? service = state.service;
    final Establishment? establishment = state.establishment;
    if (service == null || establishment == null) return;

    final result = await getFreeSchedules(
      GetFreeSchedulesParams(
        establishmentId: establishment.id,
        serviceId: service.id,
        doctorId: state.doctor?.uuid,
        date: state.dateFilter,
      ),
    );

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: BookingStatus.failure, failure: failure),
        (List<BookingSlot> schedules) => state.copyWith(
          status: BookingStatus.ready,
          schedules: schedules,
          clearFailure: true,
        ),
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
