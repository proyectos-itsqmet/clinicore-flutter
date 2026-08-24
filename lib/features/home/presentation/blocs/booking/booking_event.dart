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

/// The consultation type changed. Invalidates the day and the hour.
class BookingServiceSelected extends BookingEvent {
  const BookingServiceSelected(this.service);

  final BookingService service;

  @override
  List<Object?> get props => <Object?>[service];
}

/// The doctor changed. Invalidates the day and the hour.
class BookingDoctorSelected extends BookingEvent {
  const BookingDoctorSelected(this.doctor);

  final BookingDoctor doctor;

  @override
  List<Object?> get props => <Object?>[doctor];
}

/// The day changed. Invalidates the hour, and nothing above it.
class BookingDaySelected extends BookingEvent {
  const BookingDaySelected(this.day);

  final DateTime day;

  @override
  List<Object?> get props => <Object?>[day];
}

class BookingSlotSelected extends BookingEvent {
  const BookingSlotSelected(this.slot);

  final BookingSlot slot;

  @override
  List<Object?> get props => <Object?>[slot];
}

/// Book the selected slot.
///
/// Carries nothing: the slot is already in the state, and passing it again
/// would let a stale widget book something the patient has moved away from.
class BookingConfirmed extends BookingEvent {
  const BookingConfirmed();
}
