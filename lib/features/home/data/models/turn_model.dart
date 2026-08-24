import '../../domain/entities/appointment.dart';
import 'json_reader.dart';

/// The backend's `TurnDTO`, and the three levels it wraps.
///
/// The wire shape is four objects deep for what a card renders as one row:
///
/// ```json
/// { "id": 41, "order": 7, "status": "TURN_PENDING",
///   "schedule": {
///     "date": "2026-11-12", "hour": "09:00:00",
///     "doctor":       { "firstName": "...", "lastName": "...", "speciality": "..." },
///     "service":      { "name": "Consulta general", "price": 25.0 },
///     "stablishment": { "name": "Sede Norte" } } }
/// ```
///
/// `toEntity` FLATTENS it. That is not cosmetic: without it every widget that
/// shows a doctor writes `turn.schedule?.doctor?.firstName ?? ''`, and the day
/// one of those four levels changes name, the fix is in eleven places instead
/// of one.
///
/// `patient` is on the DTO and is deliberately ignored here. On `/api/turns/me`
/// it is always the caller — the server filtered by the token — so parsing it
/// would be storing the user's own name inside each of their appointments.
class TurnModel {
  const TurnModel({
    required this.id,
    required this.order,
    required this.status,
    this.schedule,
    this.finishedAt,
  });

  factory TurnModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> scheduleJson = readMap(json['schedule']);

    return TurnModel(
      id: readInt(json['id']),
      order: readInt(json['order']),
      status: readStringOrNull(json['status']),
      schedule: scheduleJson.isEmpty
          ? null
          : ScheduleRefModel.fromJson(scheduleJson),
      finishedAt: readDate(json['finishedAt']),
    );
  }

  final int id;
  final int order;
  final String? status;
  final ScheduleRefModel? schedule;
  final DateTime? finishedAt;

  Appointment toEntity() {
    final ScheduleRefModel? s = schedule;
    return Appointment(
      id: id,
      ticket: order,
      status: TurnStatus.fromApi(status),
      date: s?.date,
      time: s?.hour,
      doctorName: s?.doctorName,
      speciality: s?.speciality,
      serviceName: s?.serviceName,
      locationName: s?.stablishmentName,
      finishedAt: finishedAt,
    );
  }
}

/// The `ScheduleDTO` nested inside a turn, already flattened one level.
///
/// It keeps the doctor / service / stablishment as plain strings rather than
/// three more model classes: nothing in this feature needs their ids, and
/// three classes whose only job is to hold a `name` are three files that will
/// drift from the ones in `availability_model.dart` that DO need the ids.
class ScheduleRefModel {
  const ScheduleRefModel({
    this.date,
    this.hour,
    this.doctorName,
    this.speciality,
    this.serviceName,
    this.stablishmentName,
  });

  factory ScheduleRefModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> doctor = readMap(json['doctor']);
    final Map<String, dynamic> service = readMap(json['service']);
    final Map<String, dynamic> stablishment = readMap(json['stablishment']);

    final String first = readString(doctor['firstName']);
    final String last = readString(doctor['lastName']);
    final String fullName = '$first $last'.trim();

    return ScheduleRefModel(
      date: readDate(json['date']),
      hour: readTime(json['hour']),
      doctorName: fullName.isEmpty ? null : fullName,
      speciality: readStringOrNull(doctor['speciality']),
      serviceName: readStringOrNull(service['name']),
      stablishmentName: readStringOrNull(stablishment['name']),
    );
  }

  final DateTime? date;
  final String? hour;
  final String? doctorName;
  final String? speciality;
  final String? serviceName;
  final String? stablishmentName;
}

/// Spring's `Page<T>` envelope, reduced to what the app uses.
///
/// Generic over the item so turns, doctors, services and schedules all decode
/// through one place. The envelope has eleven fields; four of them matter:
/// `content`, `number`, `last` and `totalElements`. The rest —
/// `pageable.unpaged`, `sort.empty` — is one backend's pagination dialect and
/// has no business past this class.
class PageModel<T> {
  const PageModel({
    required this.content,
    required this.number,
    required this.last,
    required this.totalElements,
  });

  factory PageModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    return PageModel<T>(
      content: readMapList(json['content']).map(itemFromJson).toList(),
      number: readInt(json['number']),
      // Defaults to TRUE when the key is missing, and that direction is
      // deliberate: a caller that paginates until `last` would loop forever
      // against a malformed response if the default were false.
      last: readBool(json['last'], fallback: true),
      totalElements: readInt(json['totalElements']),
    );
  }

  final List<T> content;
  final int number;
  final bool last;
  final int totalElements;
}
