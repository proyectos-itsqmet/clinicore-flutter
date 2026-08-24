part of 'booking_bloc.dart';

enum BookingStatus {
  initial,

  /// Step 1's lists are on their way.
  loadingOptions,

  /// The doctor + service pair changed and slots are being fetched. The step
  /// controls stay usable; only the day and hour grids show a placeholder.
  loadingSlots,

  ready,

  /// The booking request is in flight.
  booking,

  /// The SERVER confirmed. [BookingState.booked] carries the created turn.
  booked,

  failure,
}

class BookingState extends Equatable {
  const BookingState._({
    required this.status,
    this.doctors = const <BookingDoctor>[],
    this.services = const <BookingService>[],
    this.availability = const BookingAvailability.empty(),
    this.service,
    this.doctor,
    this.day,
    this.slot,
    this.booked,
    this.failure,
  });

  const BookingState.initial() : this._(status: BookingStatus.initial);

  final BookingStatus status;

  // ---- Step 1's options ----
  final List<BookingDoctor> doctors;
  final List<BookingService> services;

  // ---- Steps 2 and 3, from one request ----
  final BookingAvailability availability;

  // ---- What the patient chose ----
  final BookingService? service;
  final BookingDoctor? doctor;
  final DateTime? day;
  final BookingSlot? slot;

  /// The turn the server created. Non-null exactly when [status] is
  /// [BookingStatus.booked].
  final Appointment? booked;

  final Failure? failure;

  /// Slots cannot be fetched until both are chosen.
  bool get hasPair => doctor != null && service != null;

  /// All three steps answered — what enables "Confirmar cita".
  bool get isComplete => hasPair && day != null && slot != null;

  bool get isBusy =>
      status == BookingStatus.loadingOptions ||
      status == BookingStatus.loadingSlots ||
      status == BookingStatus.booking;

  bool get isFirstLoad =>
      status == BookingStatus.loadingOptions && doctors.isEmpty;

  bool get isSessionExpired => failure is SessionExpiredFailure;

  /// The pair is chosen, the fetch finished, and there is nothing to offer.
  /// Distinct from "still loading" and from "pick a doctor first" — those three
  /// look identical as an empty grid and mean completely different things.
  bool get hasNoAvailability =>
      hasPair &&
      status != BookingStatus.loadingSlots &&
      availability.bookableDays.isEmpty;

  List<DateTime> get bookableDays => availability.bookableDays;

  /// Every slot on the selected day, taken ones included — the board strikes
  /// them through rather than hiding them.
  List<BookingSlot> get slotsForDay =>
      day == null ? const <BookingSlot>[] : availability.slotsOn(day!);

  BookingState copyWith({
    BookingStatus? status,
    List<BookingDoctor>? doctors,
    List<BookingService>? services,
    BookingAvailability? availability,
    BookingService? service,
    BookingDoctor? doctor,
    DateTime? day,
    BookingSlot? slot,
    Appointment? booked,
    Failure? failure,
    bool clearDay = false,
    bool clearSlot = false,
    bool clearBooked = false,
    bool clearFailure = false,
  }) {
    return BookingState._(
      status: status ?? this.status,
      doctors: doctors ?? this.doctors,
      services: services ?? this.services,
      availability: availability ?? this.availability,
      service: service ?? this.service,
      doctor: doctor ?? this.doctor,
      // The four `clear*` flags exist because `copyWith` with a nullable
      // parameter cannot say "set this back to nothing" — and a stale hour
      // surviving a change of doctor is exactly the bug that produces: it
      // would book the previous doctor's slot.
      day: clearDay ? null : (day ?? this.day),
      slot: clearSlot ? null : (slot ?? this.slot),
      booked: clearBooked ? null : (booked ?? this.booked),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    doctors,
    services,
    availability,
    service,
    doctor,
    day,
    slot,
    booked,
    failure,
  ];
}
