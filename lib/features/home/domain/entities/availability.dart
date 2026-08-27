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

  /// The concrete instant this slot begins.
  ///
  /// [date] is LOCAL midnight (see `readDate`) and [time] is `HH:mm`, so
  /// neither field can answer "has this already passed?" alone — a slot at
  /// 09:00 yesterday is past at 08:00 today, and comparing the hours would say
  /// the opposite.
  ///
  /// ## When the hour cannot be read
  ///
  /// `readTime` returns the raw string untouched for anything it does not
  /// recognise as `HH:mm`, so [time] is not guaranteed parseable. This falls
  /// back to the END of the day rather than to midnight, because the honest
  /// reading of an unparseable hour is "we know the day, not the moment" —
  /// midnight would hide every slot of today, and the clinic would lose a
  /// day's bookable inventory to a formatting change on the wire.
  DateTime get startsAt {
    final List<String> parts = time.split(':');
    final int? hour = parts.isEmpty ? null : int.tryParse(parts[0]);
    final int? minute = parts.length < 2 ? null : int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Whether this slot can still be booked at [now].
  ///
  /// STRICTLY after: a slot starting this very minute is not offered. That is
  /// the same cut `TurnService.requireUpcoming` makes on the server, and the
  /// two agreeing is what keeps the grid from drawing a chip the server would
  /// then refuse.
  bool isUpcomingAt(DateTime now) => startsAt.isAfter(now);

  @override
  List<Object?> get props => <Object?>[scheduleId, date, time, isFree];
}
