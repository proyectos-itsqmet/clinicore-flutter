import '../../domain/entities/availability.dart';
import 'json_reader.dart';

/// The backend's `DoctorDTO`, reduced to what a patient picks from.
///
/// The DTO also carries `email`, `ci`, `stablishments` and `services`. None of
/// it is parsed: a patient does not choose a doctor by cedula, and a model that
/// holds a field nobody reads is a field somebody eventually logs.
class BookingDoctorModel {
  const BookingDoctorModel({
    required this.uuid,
    required this.firstName,
    required this.lastName,
    this.speciality,
  });

  factory BookingDoctorModel.fromJson(Map<String, dynamic> json) {
    return BookingDoctorModel(
      uuid: readString(json['uuid']),
      firstName: readString(json['firstName']),
      lastName: readString(json['lastName']),
      speciality: readStringOrNull(json['speciality']),
    );
  }

  final String uuid;
  final String firstName;
  final String lastName;
  final String? speciality;

  BookingDoctor toEntity() {
    final String name = '$firstName $lastName'.trim();
    return BookingDoctor(
      uuid: uuid,
      // Never blank: a chip with no label is untappable in practice, and a
      // doctor row with no name is a data problem the patient should see.
      fullName: name.isEmpty ? 'Doctor sin nombre' : name,
      speciality: speciality,
    );
  }
}

/// The backend's `ServicioDTO`.
///
/// `price` is a Java `Float`, which Jackson serialises as `25.0` — and
/// `discount` is nullable. Both go through the tolerant readers because a
/// `double` read as an `int` is a runtime cast error in Dart, and the wire can
/// legitimately send either.
class BookingServiceModel {
  const BookingServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.discount,
  });

  factory BookingServiceModel.fromJson(Map<String, dynamic> json) {
    return BookingServiceModel(
      id: readInt(json['id']),
      name: readString(json['name']),
      price: readDouble(json['price']),
      discount: readDoubleOrNull(json['discount']),
    );
  }

  final int id;
  final String name;
  final double price;
  final double? discount;

  BookingService toEntity() => BookingService(
    id: id,
    name: name.isEmpty ? 'Consulta' : name,
    price: price,
    discount: discount,
  );
}

/// The backend's `ScheduleDTO` as a bookable slot.
///
/// `toEntity` returns NULL when the row cannot become a chip — no id, no date,
/// or no hour. All three are possible on the wire and none of them can be
/// rendered: a slot with no `scheduleId` has nothing to POST, one with no date
/// cannot be placed on a day, and one with no hour has no label. Dropping them
/// HERE is what lets [BookingSlot] declare all three non-nullable, so nothing
/// above this line needs a null check per field.
class BookingSlotModel {
  const BookingSlotModel({
    required this.id,
    this.date,
    this.hour,
    this.status,
  });

  factory BookingSlotModel.fromJson(Map<String, dynamic> json) {
    return BookingSlotModel(
      id: readIntOrNull(json['id']),
      date: readDate(json['date']),
      hour: readTime(json['hour']),
      status: readStringOrNull(json['status']),
    );
  }

  final int? id;
  final DateTime? date;
  final String? hour;
  final String? status;

  /// `STATUS_FREE` is the only bookable one. `STATUS_OCCUPIED` shows struck
  /// through; `STATUS_UNAVAILABLE` also shows struck through — from the
  /// patient's side "taken" and "blocked" are the same answer, and explaining
  /// the difference would mean explaining the clinic's internal calendar.
  bool get isFree => status == 'STATUS_FREE';

  BookingSlot? toEntity() {
    final int? scheduleId = id;
    final DateTime? day = date;
    final String? label = hour;
    if (scheduleId == null || day == null || label == null) return null;

    return BookingSlot(
      scheduleId: scheduleId,
      date: day,
      time: label,
      isFree: isFree,
    );
  }
}
