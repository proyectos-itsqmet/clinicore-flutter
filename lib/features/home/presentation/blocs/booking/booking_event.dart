part of 'booking_bloc.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load step 1. Fired once, on first build.
class BookingStarted extends BookingEvent {
  const BookingStarted();
}

/// The search box on step 1 changed. Filters [BookingState.establishments]
/// locally — see [BookingState.visibleEstablishments].
class BookingEstablishmentSearchChanged extends BookingEvent {
  const BookingEstablishmentSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// Step 1 answered. Invalidates everything chosen below it and moves to
/// step 2 — mirrors `selectEstablishment`.
class BookingEstablishmentSelected extends BookingEvent {
  const BookingEstablishmentSelected(this.establishment);

  final Establishment establishment;

  @override
  List<Object?> get props => <Object?>[establishment];
}

/// Step 2 answered: a service, and OPTIONALLY a doctor. Invalidates the
/// chosen schedule and moves to step 3 — mirrors `selectServiceAndDoctor`.
class BookingServiceAndDoctorSelected extends BookingEvent {
  const BookingServiceAndDoctorSelected(this.service, this.doctor);

  final BookingService service;
  final BookingDoctor? doctor;

  @override
  List<Object?> get props => <Object?>[service, doctor];
}

/// The date filter on step 3 changed. `null` means "todos los dias" — the
/// web flow's cleared filter. "Hoy" / "Manana" are resolved to a concrete
/// [DateTime] by the SCREEN before dispatching this, so the bloc never calls
/// `DateTime.now()` itself and stays trivially testable.
class BookingDateFilterChanged extends BookingEvent {
  const BookingDateFilterChanged(this.date);

  final DateTime? date;

  @override
  List<Object?> get props => <Object?>[date];
}

/// Step 3 answered, but not booked yet.
class BookingScheduleSelected extends BookingEvent {
  const BookingScheduleSelected(this.schedule);

  final BookingSlot schedule;

  @override
  List<Object?> get props => <Object?>[schedule];
}

/// Books the selected schedule. Carries nothing: the schedule is already in
/// the state, and passing it again would let a stale widget book something
/// the patient has moved away from.
class BookingConfirmed extends BookingEvent {
  const BookingConfirmed();
}

/// Moves BACK to an earlier step. Mirrors `goToStep`: a request to go
/// sideways or forward is silently ignored — see
/// [BookingState.canGoBackTo].
class BookingStepBackRequested extends BookingEvent {
  const BookingStepBackRequested(this.step);

  final BookingStep step;

  @override
  List<Object?> get props => <Object?>[step];
}

/// "Agendar otro turno" — mirrors `resetBooking`. Forgets every selection but
/// keeps the sedes already loaded; there is no reason to ask the server for
/// the same list again.
class BookingReset extends BookingEvent {
  const BookingReset();
}
