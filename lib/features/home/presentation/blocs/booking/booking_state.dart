part of 'booking_bloc.dart';

/// The four steps of "Agendar", in the order the patient walks them.
/// Mirrors `clinicore-angular`'s `currentStep` signal (1..4).
enum BookingStep { establishment, serviceAndDoctor, schedule, confirmed }

enum BookingStatus {
  initial,

  /// Step 1's list is on its way.
  loadingEstablishments,

  /// Step 2's services (each with its doctors) are on their way.
  loadingServices,

  /// Step 3's free slots are on their way.
  loadingSchedules,

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
    this.step = BookingStep.establishment,
    this.establishments = const <Establishment>[],
    this.establishmentSearch = '',
    this.establishment,
    this.servicesWithDoctors = const <ServiceWithDoctors>[],
    this.service,
    this.doctor,
    this.schedules = const <BookingSlot>[],
    this.dateFilter,
    this.schedule,
    this.booked,
    this.failure,
  });

  const BookingState.initial() : this._(status: BookingStatus.initial);

  final BookingStatus status;
  final BookingStep step;

  // ---- Step 1: Sede ----
  final List<Establishment> establishments;
  final String establishmentSearch;
  final Establishment? establishment;

  // ---- Step 2: Servicio y Doctor ----
  final List<ServiceWithDoctors> servicesWithDoctors;
  final BookingService? service;

  /// Optional — step 2 lets a patient skip picking a specific doctor.
  final BookingDoctor? doctor;

  // ---- Step 3: Horario ----
  final List<BookingSlot> schedules;

  /// `null` means "todos los dias" — the web flow's cleared date filter.
  final DateTime? dateFilter;
  final BookingSlot? schedule;

  // ---- Step 4: Confirmado ----
  /// The turn the server created. Non-null exactly when [step] is
  /// [BookingStep.confirmed].
  final Appointment? booked;

  final Failure? failure;

  /// Step 1's list, narrowed by [establishmentSearch] — case-insensitive,
  /// over the name only.
  ///
  /// Filtered HERE rather than re-fetched from the server: this app already
  /// asks `GET /api/stablishments` for the whole first page (see
  /// `BookingRemoteDataSourceImpl.fetchEstablishments`), so a round trip per
  /// keystroke would add latency with no new data behind it.
  List<Establishment> get visibleEstablishments {
    final String query = establishmentSearch.trim().toLowerCase();
    if (query.isEmpty) return establishments;
    return establishments
        .where((Establishment e) => e.name.toLowerCase().contains(query))
        .toList();
  }

  bool get isBusy =>
      status == BookingStatus.loadingEstablishments ||
      status == BookingStatus.loadingServices ||
      status == BookingStatus.loadingSchedules ||
      status == BookingStatus.booking;

  bool get isFirstLoad =>
      status == BookingStatus.loadingEstablishments && establishments.isEmpty;

  bool get isSessionExpired => failure is SessionExpiredFailure;

  /// Step 2 answered, the fetch finished SUCCESSFULLY, and there is nothing
  /// to offer. Distinct from "still loading" and from "the fetch failed":
  /// all three can look identical as an empty list, and `status == ready`
  /// is what tells them apart — a failure has its OWN message, and showing
  /// this one on top of it would be two contradictory explanations for the
  /// same empty screen.
  bool get hasNoServices =>
      step == BookingStep.serviceAndDoctor &&
      status == BookingStatus.ready &&
      servicesWithDoctors.isEmpty;

  /// Step 3 answered, the fetch finished SUCCESSFULLY, and there is nothing
  /// to offer. See [hasNoServices] for why this checks `ready` specifically
  /// rather than merely "not loading".
  bool get hasNoSchedules =>
      step == BookingStep.schedule &&
      status == BookingStatus.ready &&
      schedules.isEmpty;

  /// Whether the patient can move BACK to [target].
  ///
  /// Mirrors `goToStep`'s `step < currentStep()`: strictly EARLIER, never
  /// sideways or forward. The four numbered tabs on the web page enforce the
  /// same rule through `[disabled]`; here it is enforced where a tap cannot
  /// bypass it.
  bool canGoBackTo(BookingStep target) => target.index < step.index;

  /// The step one back from here, or null when there is nothing behind this
  /// one INSIDE the wizard.
  ///
  /// This is the single definition of what "back" means in this flow, and it
  /// has two callers on purpose: the header's "Volver" link and the device's
  /// own back button (`_BookingBackGuard`). When the two disagreed — which is
  /// the state this screen shipped in, with the header knowing how to step
  /// back and the hardware button not — the patient got thrown out of a
  /// half-filled wizard by the gesture they use most.
  ///
  /// Step 4 returns null even though [canGoBackTo] would happily accept step
  /// 2 or 3 from there: the turn is already booked, so there is no selection
  /// left to undo. Stepping "back" into the schedule list would show a
  /// chooser for a slot the server already took. What back does there is
  /// decided by `_BookingBackGuard`, not here.
  BookingStep? get previousStep => switch (step) {
    BookingStep.establishment => null,
    BookingStep.serviceAndDoctor => BookingStep.establishment,
    BookingStep.schedule => BookingStep.serviceAndDoctor,
    BookingStep.confirmed => null,
  };

  BookingState copyWith({
    BookingStatus? status,
    BookingStep? step,
    List<Establishment>? establishments,
    String? establishmentSearch,
    Establishment? establishment,
    List<ServiceWithDoctors>? servicesWithDoctors,
    BookingService? service,
    BookingDoctor? doctor,
    List<BookingSlot>? schedules,
    DateTime? dateFilter,
    BookingSlot? schedule,
    Appointment? booked,
    Failure? failure,
    bool clearService = false,
    bool clearDoctor = false,
    bool clearDateFilter = false,
    bool clearSchedule = false,
    bool clearBooked = false,
    bool clearFailure = false,
  }) {
    return BookingState._(
      status: status ?? this.status,
      step: step ?? this.step,
      establishments: establishments ?? this.establishments,
      establishmentSearch: establishmentSearch ?? this.establishmentSearch,
      establishment: establishment ?? this.establishment,
      servicesWithDoctors: servicesWithDoctors ?? this.servicesWithDoctors,
      service: clearService ? null : (service ?? this.service),
      // The `clear*` flags exist because `copyWith` with a nullable
      // parameter cannot say "set this back to nothing" — and a stale
      // doctor or schedule surviving a change of sede is exactly the bug
      // that produces: it would scope a request to, or book, the wrong
      // thing.
      doctor: clearDoctor ? null : (doctor ?? this.doctor),
      schedules: schedules ?? this.schedules,
      dateFilter: clearDateFilter ? null : (dateFilter ?? this.dateFilter),
      schedule: clearSchedule ? null : (schedule ?? this.schedule),
      booked: clearBooked ? null : (booked ?? this.booked),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    step,
    establishments,
    establishmentSearch,
    establishment,
    servicesWithDoctors,
    service,
    doctor,
    schedules,
    dateFilter,
    schedule,
    booked,
    failure,
  ];
}
