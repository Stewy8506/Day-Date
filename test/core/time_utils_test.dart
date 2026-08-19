import 'package:flutter_test/flutter_test.dart';

import 'package:day_date/core/utils/time_utils.dart';

void main() {
  group('overlaps', () {
    test('overlapping ranges return true', () {
      expect(overlaps(600, 720, 700, 800), isTrue);
    });

    test('contained range returns true', () {
      expect(overlaps(600, 900, 700, 800), isTrue);
    });

    test('disjoint ranges return false', () {
      expect(overlaps(600, 700, 800, 900), isFalse);
    });

    test('adjacent ranges (touching) return false', () {
      expect(overlaps(600, 700, 700, 800), isFalse);
    });

    test('identical ranges return true', () {
      expect(overlaps(600, 700, 600, 700), isTrue);
    });
  });

  group('formatMinutes', () {
    test('midnight is 12:00 AM', () {
      expect(formatMinutes(0), '12:00 AM');
    });

    test('600 is 10:00 AM', () {
      expect(formatMinutes(600), '10:00 AM');
    });

    test('720 is 12:00 PM', () {
      expect(formatMinutes(720), '12:00 PM');
    });

    test('810 is 1:30 PM', () {
      expect(formatMinutes(810), '1:30 PM');
    });

    test('1170 is 7:30 PM', () {
      expect(formatMinutes(1170), '7:30 PM');
    });
  });

  group('formatDuration', () {
    test('0 minutes', () {
      expect(formatDuration(0), '0m');
    });

    test('90 minutes', () {
      expect(formatDuration(90), '1h 30m');
    });

    test('60 minutes', () {
      expect(formatDuration(60), '1h');
    });

    test('45 minutes', () {
      expect(formatDuration(45), '45m');
    });
  });

  group('timeToMinutes', () {
    test('10:00 AM', () {
      expect(timeToMinutes(10, 0), 600);
    });

    test('13:50', () {
      expect(timeToMinutes(13, 50), 830);
    });
  });

  group('computeFreeSlots', () {
    test('no occupied blocks yields full day', () {
      final slots = computeFreeSlots(
        dayOfWeek: 1,
        occupied: [],
        dayStart: 360,
        dayEnd: 1439,
        minSlotMinutes: 90,
      );
      expect(slots.length, 1);
      expect(slots[0].startMinutes, 360);
      expect(slots[0].endMinutes, 1439);
    });

    test('single occupied block yields two slots', () {
      final slots = computeFreeSlots(
        dayOfWeek: 1,
        occupied: [(start: 600, end: 720)],
        dayStart: 360,
        dayEnd: 1439,
        minSlotMinutes: 90,
      );
      expect(slots.length, 2);
      expect(slots[0].startMinutes, 360);
      expect(slots[0].endMinutes, 600);
      expect(slots[1].startMinutes, 720);
      expect(slots[1].endMinutes, 1439);
    });

    test('small gap is filtered out', () {
      final slots = computeFreeSlots(
        dayOfWeek: 1,
        occupied: [
          (start: 360, end: 700),
          (start: 750, end: 1439),
        ],
        dayStart: 360,
        dayEnd: 1439,
        minSlotMinutes: 90,
      );
      // Gap is 700-750 = 50 min, below 90 min threshold.
      expect(slots, isEmpty);
    });

    test('multiple blocks yield correct free slots', () {
      final slots = computeFreeSlots(
        dayOfWeek: 1,
        occupied: [
          (start: 360, end: 480), // 6-8
          (start: 600, end: 720), // 10-12
          (start: 1170, end: 1290), // 19:30-21:30
        ],
        dayStart: 360,
        dayEnd: 1439,
        minSlotMinutes: 90,
      );
      // Free: 480-600 (120min ✓), 720-1170 (450min ✓), 1290-1439 (149min ✓)
      expect(slots.length, 3);
    });
  });
}
