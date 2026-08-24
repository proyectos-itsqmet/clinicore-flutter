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

  /// Same calendar day, ignoring any time component.
  bool isOn(DateTime day) =>
      date.year == day.year && date.month == day.month && date.day == day.day;

  @override
  List<Object?> get props => <Object?>[scheduleId, date, time, isFree];
}

/// Every slot the server returned for the current filters, plus the two views
/// the three-step flow reads off it.
///
/// ONE fetch feeds both steps. Asking the server once for a date range and
/// deriving the days from it is what makes step 2 instant after step 1 — the
/// alternative is a request per day, which is a request per tap.
class BookingAvailability extends Equatable {
  const BookingAvailability({required this.slots});

  const BookingAvailability.empty() : slots = const <BookingSlot>[];

  final List<BookingSlot> slots;

  /// The distinct days that have at least one FREE slot, in order.
  ///
  /// Filtered on free rather than showing every day the clinic has an agenda:
  /// a day chip that opens onto a grid of struck-through hours is a tap that
  /// could not lead anywhere.
  List<DateTime> get bookableDays {
    final List<DateTime> days = <DateTime>[];
    for (final BookingSlot slot in slots) {
      if (!slot.isFree) continue;
      final DateTime day = DateTime(
        slot.date.year,
        slot.date.month,
        slot.date.day,
      );
      if (!days.any((DateTime d) => d == day)) days.add(day);
    }
    days.sort();
    return days;
  }

  /// Every slot on [day], free or not, in time order.
  ///
  /// Taken slots are INCLUDED on purpose — the board strikes them through
  /// instead of hiding them, and its own note says why: seeing that 08:40 is
  /// gone is what makes 09:00 feel like a real appointment rather than a
  /// suggestion.
  List<BookingSlot> slotsOn(DateTime day) {
    final List<BookingSlot> result = slots
        .where((BookingSlot slot) => slot.isOn(day))
        .toList();
    result.sort((BookingSlot a, BookingSlot b) => a.time.compareTo(b.time));
    return result;
  }

  @override
  List<Object?> get props => <Object?>[slots];
}
