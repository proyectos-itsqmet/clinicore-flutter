import 'package:equatable/equatable.dart';

/// A doctor, as the booking screen needs them.
///
/// Not the admin panel's doctor: no email, no cedula, no assigned sedes. A
/// patient picking who to see needs a name and a speciality, and carrying the
/// rest through the domain would mean this entity changes every time the
/// staff-facing DTO does.
class BookingDoctor extends Equatable {
  const BookingDoctor({
    required this.uuid,
    required this.fullName,
    this.speciality,
  });

  final String uuid;
  final String fullName;
  final String? speciality;

  /// `Dr(a). Perez / Cardiologia` — what the chip shows.
  String get chipLabel =>
      speciality == null ? fullName : '$fullName / $speciality';

  @override
  List<Object?> get props => <Object?>[uuid, fullName, speciality];
}

/// A bookable service, with the only two money fields that exist.
///
/// ## About the price the board draws
///
/// `design/Mobile.dc.html` shows a struck-through list price and a lower "Con
/// tu plan" price. **There are no plans.** `insurers`, `coverage_plans` and
/// `patient_coverage` do not exist on the server, so an insurer-specific price
/// cannot be computed and inventing one would be inventing a number a patient
/// might budget around.
///
/// What DOES exist is `services.discount`, a flat amount off this service for
/// everyone. So the screen shows [price] struck through and [finalPrice]
/// highlighted only when there is a real discount — and labels it as a
/// discount, not as a plan.
class BookingService extends Equatable {
  const BookingService({
    required this.id,
    required this.name,
    required this.price,
    this.discount,
  });

  final int id;
  final String name;
  final double price;

  /// A flat amount off, not a percentage. Null or 0 means no discount.
  final double? discount;

  bool get hasDiscount => (discount ?? 0) > 0;

  /// Clamped at zero: a discount larger than the price is a data-entry error,
  /// and showing `USD -5` would make the app look broken rather than the row.
  double get finalPrice =>
      hasDiscount ? (price - discount!).clamp(0, price) : price;

  @override
  List<Object?> get props => <Object?>[id, name, price, discount];
}

/// One bookable slot: a concrete schedule row.
///
/// [scheduleId] is what `POST /api/turns` needs, and it is the reason slots are
/// entities rather than formatted strings — a chip that only knows `"09:00"`
/// cannot book anything.
class BookingSlot extends Equatable {
  const BookingSlot({
    required this.scheduleId,
    required this.date,
    required this.time,
    required this.isFree,
  });

  final int scheduleId;
  final DateTime date;

  /// `HH:mm`, zero-padded — which is also what makes string sorting correct.
  final String time;

  final bool isFree;

  @override
  List<Object?> get props => <Object?>[scheduleId, date, time, isFree];
}
