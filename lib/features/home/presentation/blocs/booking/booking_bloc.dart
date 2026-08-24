import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/entities/appointment.dart';
import '../../../domain/entities/availability.dart';
import '../../../domain/repositories/booking_repository.dart';
import '../../../domain/usecases/booking_usecases.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Drives the three steps of "Agendar" and the booking itself.
///
/// ## Availability is fetched when the PAIR is complete, not on every tap
///
/// A slot search needs both a doctor and a service. Selecting either one fires
/// [_maybeLoadAvailability], which only calls the server once both are set —
/// otherwise the first tap on a doctor chip would request every slot for a
/// service the patient has not chosen yet.
///
/// ## Selections cascade downward, and only downward
///
/// Picking a different doctor invalidates the day and the hour: those slots
/// belonged to the previous doctor and booking one would book the wrong
/// appointment. Picking a different day invalidates only the hour. That is
/// what `copyWith`'s `clearDay` / `clearSlot` flags exist for — a nullable
/// parameter cannot express "set this back to nothing".
///
/// ## The confirmation is the SERVER's, not the tap's
///
/// [BookingStatus.booked] is emitted from the response, and carries the created
/// [Appointment] so the screen can show the real ticket number. Flipping a
/// local `_confirmed` flag on tap — which is what the screen did while it was
/// sample data — would show a green "Reservado" bar over a request that can
/// still fail with "el cupo ya fue tomado".
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc({
    required this.getBookingOptions,
    required this.getAvailability,
    required this.bookSlot,
  }) : super(const BookingState.initial()) {
    on<BookingStarted>(_onStarted);
    on<BookingServiceSelected>(_onServiceSelected);
    on<BookingDoctorSelected>(_onDoctorSelected);
    on<BookingDaySelected>(_onDaySelected);
    on<BookingSlotSelected>(_onSlotSelected);
    on<BookingConfirmed>(_onConfirmed);
  }

  final GetBookingOptions getBookingOptions;
  final GetAvailability getAvailability;
  final BookSlot bookSlot;

  Future<void> _onStarted(
    BookingStarted event,
    Emitter<BookingState> emit,
  ) async {
    emit(state.copyWith(status: BookingStatus.loadingOptions, clearFailure: true));

    final result = await getBookingOptions(const NoParams());

    await result.fold(
      (Failure failure) async => emit(
        state.copyWith(status: BookingStatus.failure, failure: failure),
      ),
      (BookingOptions options) async {
        // The first service is preselected because the board's type switch
        // always shows one as active — a segmented control with nothing
        // selected is a control the patient has to discover.
        final BookingService? service = options.services.isEmpty
            ? null
            : options.services.first;

        emit(
          state.copyWith(
            status: BookingStatus.ready,
            doctors: options.doctors,
            services: options.services,
            service: service,
            clearFailure: true,
          ),
        );
      },
    );
  }

  Future<void> _onServiceSelected(
    BookingServiceSelected event,
    Emitter<BookingState> emit,
  ) async {
    if (event.service == state.service) return;

    emit(
      state.copyWith(
        service: event.service,
        // A different service means different slots, so anything chosen below
        // this step is no longer valid.
        availability: const BookingAvailability.empty(),
        clearDay: true,
        clearSlot: true,
        clearBooked: true,
      ),
    );

    await _maybeLoadAvailability(emit);
  }

  Future<void> _onDoctorSelected(
    BookingDoctorSelected event,
    Emitter<BookingState> emit,
  ) async {
    if (event.doctor == state.doctor) return;

    emit(
      state.copyWith(
        doctor: event.doctor,
        availability: const BookingAvailability.empty(),
        clearDay: true,
        clearSlot: true,
        clearBooked: true,
      ),
    );

    await _maybeLoadAvailability(emit);
  }

  void _onDaySelected(BookingDaySelected event, Emitter<BookingState> emit) {
    emit(state.copyWith(day: event.day, clearSlot: true, clearBooked: true));
  }

  void _onSlotSelected(BookingSlotSelected event, Emitter<BookingState> emit) {
    emit(state.copyWith(slot: event.slot, clearBooked: true));
  }

  Future<void> _onConfirmed(
    BookingConfirmed event,
    Emitter<BookingState> emit,
  ) async {
    final BookingSlot? slot = state.slot;
    if (slot == null) return;

    emit(state.copyWith(status: BookingStatus.booking, clearFailure: true));

    final result = await bookSlot(slot.scheduleId);

    await result.fold(
      (Failure failure) async => emit(
        state.copyWith(status: BookingStatus.failure, failure: failure),
      ),
      (Appointment appointment) async {
        emit(
          state.copyWith(
            status: BookingStatus.booked,
            booked: appointment,
            clearFailure: true,
          ),
        );

        // The slot just taken is no longer free, and the cheapest correct way
        // to reflect that is to ask again. Patching the local list would work
        // until two people book at once, which in a clinic is Tuesday morning.
        await _maybeLoadAvailability(emit, keepBooked: true);
      },
    );
  }

  /// Loads slots once BOTH a doctor and a service are chosen.
  Future<void> _maybeLoadAvailability(
    Emitter<BookingState> emit, {
    bool keepBooked = false,
  }) async {
    final BookingDoctor? doctor = state.doctor;
    final BookingService? service = state.service;
    if (doctor == null || service == null) return;

    emit(
      state.copyWith(
        status: BookingStatus.loadingSlots,
        clearFailure: true,
        clearBooked: !keepBooked,
      ),
    );

    final result = await getAvailability(
      GetAvailabilityParams(doctorId: doctor.uuid, serviceId: service.id),
    );

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: BookingStatus.failure, failure: failure),
        (BookingAvailability availability) {
          // Preselect the first bookable day, so the hour grid is populated
          // instead of empty — the board never draws step 3 blank.
          final List<DateTime> days = availability.bookableDays;
          return state.copyWith(
            status: keepBooked ? BookingStatus.booked : BookingStatus.ready,
            availability: availability,
            day: days.isEmpty ? null : days.first,
            clearDay: days.isEmpty,
            clearSlot: true,
            clearFailure: true,
          );
        },
      ),
    );
  }
}
