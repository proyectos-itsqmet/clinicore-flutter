import 'package:equatable/equatable.dart';

/// Where a turn stands, as the API spells it.
///
/// [waiting] maps the wire value `TURN_WAITNG` — the typo is the server's, and
/// it is the string stored in the database, so the client has to match it.
/// Correcting it is a data migration, not a rename, and doing it on one side
/// only would break the mapping silently.
///
/// [unknown] absorbs anything new: a status the app has never heard of shows
/// up as an appointment with no pill rather than a crash.
enum TurnStatus {
  pending,
  waiting,
  inTreatment,
  treated,
  cancelled,
  unknown;

  static TurnStatus fromApi(String? value) => switch (value) {
    'TURN_PENDING' => TurnStatus.pending,
    'TURN_WAITNG' => TurnStatus.waiting,
    'TURN_IN_TREATMENT' => TurnStatus.inTreatment,
    'TURN_TREATED' => TurnStatus.treated,
    'TURN_CANCELLED' => TurnStatus.cancelled,
    _ => TurnStatus.unknown,
  };

  String? get apiValue => switch (this) {
    TurnStatus.pending => 'TURN_PENDING',
    TurnStatus.waiting => 'TURN_WAITNG',
    TurnStatus.inTreatment => 'TURN_IN_TREATMENT',
    TurnStatus.treated => 'TURN_TREATED',
    TurnStatus.cancelled => 'TURN_CANCELLED',
    TurnStatus.unknown => null,
  };

  /// Still ahead of the patient: it is on the "Proximas" tab.
  ///
  /// Derived from the status and NOT from the date, deliberately. A turn the
  /// clinic already marked attended belongs in the past even if its date is
  /// tomorrow (someone came early, someone fixed a typo), and a cancelled one
  /// is never upcoming. The date is what ORDERS the list; the status is what
  /// decides which list.
  bool get isUpcoming => switch (this) {
    TurnStatus.pending || TurnStatus.waiting || TurnStatus.inTreatment => true,
    TurnStatus.treated || TurnStatus.cancelled || TurnStatus.unknown => false,
  };
}

/// One booked appointment, flattened.
///
/// The wire shape is a `TurnDTO` wrapping a `ScheduleDTO` wrapping a doctor, a
/// service and a stablishment — four levels for what the screen reads as one
/// row. Flattening happens in the model's `toEntity`, so the UI never writes
/// `turn.schedule?.doctor?.firstName ?? ''` three times on one card.
///
/// Every field below the ticket is nullable because every one of those nested
/// objects is nullable on the wire, and a turn whose schedule was deleted is a
/// real row the server will happily return.
class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.ticket,
    required this.status,
    this.date,
    this.time,
    this.doctorName,
    this.speciality,
    this.serviceName,
    this.locationName,
    this.finishedAt,
  });

  final int id;

  /// `TurnDTO.order` — the number called in the waiting room.
  final int ticket;

  final TurnStatus status;

  /// The appointment's own day, from its schedule. Null when the schedule is
  /// gone.
  final DateTime? date;

  /// `HH:mm`, already trimmed of the seconds the server sends.
  final String? time;

  final String? doctorName;
  final String? speciality;
  final String? serviceName;
  final String? locationName;

  /// When the clinic marked it attended. Used by the history tab, which cares
  /// about when the visit actually happened.
  final DateTime? finishedAt;

  bool get isUpcoming => status.isUpcoming;

  @override
  List<Object?> get props => <Object?>[
    id,
    ticket,
    status,
    date,
    time,
    doctorName,
    speciality,
    serviceName,
    locationName,
    finishedAt,
  ];
}

/// A page of appointments plus what the caller needs to ask for the next one.
///
/// The Spring envelope has eleven fields; this keeps the three the app uses.
/// Carrying the whole thing into the domain would drag `pageable.unpaged` and
/// `sort.empty` — one backend's pagination dialect — across the boundary.
class AppointmentPage extends Equatable {
  const AppointmentPage({
    required this.items,
    required this.page,
    required this.isLast,
    required this.totalElements,
  });

  const AppointmentPage.empty()
    : items = const <Appointment>[],
      page = 0,
      isLast = true,
      totalElements = 0;

  final List<Appointment> items;

  /// Zero-based, the way the API counts.
  final int page;
  final bool isLast;
  final int totalElements;

  @override
  List<Object?> get props => <Object?>[items, page, isLast, totalElements];
}
