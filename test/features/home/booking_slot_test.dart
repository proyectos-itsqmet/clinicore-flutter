import 'package:clinicore_flutter/features/home/domain/entities/availability.dart';
import 'package:flutter_test/flutter_test.dart';

/// [BookingSlot.startsAt] and [BookingSlot.isUpcomingAt] — the rule that keeps
/// a cupo whose hour is gone off the booking grid.
///
/// It matters that this is tested at the ENTITY and not only through the bloc:
/// the same question is asked on the server by `TurnService.requireUpcoming`,
/// and the two have to cut at the same place. A chip the app offers and the
/// server then refuses is worse than no chip.
void main() {
  BookingSlot slotAt(DateTime day, String time) => BookingSlot(
    scheduleId: 1,
    date: day,
    time: time,
    isFree: true,
  );

  group('startsAt', () {
    test('combines the date with the HH:mm hour', () {
      final BookingSlot slot = slotAt(DateTime(2026, 11, 12), '09:30');

      expect(slot.startsAt, DateTime(2026, 11, 12, 9, 30));
    });

    test('reads midnight as the start of the day, not the end', () {
      final BookingSlot slot = slotAt(DateTime(2026, 11, 12), '00:00');

      expect(slot.startsAt, DateTime(2026, 11, 12));
    });

    test('falls back to the END of the day when the hour is unreadable', () {
      // `readTime` hands the raw string through untouched when it does not
      // look like `HH:mm`. Falling back to midnight would hide every slot of
      // the current day over a formatting change on the wire; the end of the
      // day hides them only once the day itself is over.
      final BookingSlot slot = slotAt(DateTime(2026, 11, 12), 'manana');

      expect(slot.startsAt, DateTime(2026, 11, 12, 23, 59));
    });
  });

  group('isUpcomingAt', () {
    final DateTime day = DateTime(2026, 11, 12);

    test('an hour still ahead today is upcoming', () {
      expect(
        slotAt(day, '10:00').isUpcomingAt(DateTime(2026, 11, 12, 9, 30)),
        isTrue,
      );
    });

    test('an hour already gone today is not', () {
      expect(
        slotAt(day, '09:00').isUpcomingAt(DateTime(2026, 11, 12, 9, 30)),
        isFalse,
      );
    });

    test('a slot starting exactly now is not offered', () {
      // Strictly after, matching `TurnService.requireUpcoming`. Offering a
      // slot at the minute it begins means offering one the server rejects.
      expect(
        slotAt(day, '09:00').isUpcomingAt(DateTime(2026, 11, 12, 9)),
        isFalse,
      );
    });

    test('yesterday is past even at an hour that has not arrived today', () {
      // The assertion that catches an implementation comparing hours alone:
      // 09:00 is "after" 08:00, on a day that ended last night.
      expect(
        slotAt(day, '09:00').isUpcomingAt(DateTime(2026, 11, 13, 8)),
        isFalse,
      );
    });

    test('tomorrow is upcoming even at an hour already gone today', () {
      expect(
        slotAt(DateTime(2026, 11, 13), '09:00')
            .isUpcomingAt(DateTime(2026, 11, 12, 20)),
        isTrue,
      );
    });
  });
}
