/// Time manipulation utilities for the Day-Date engine.
library;

/// Represents a gap of free time on a specific day.
class FreeSlot {
  final int dayOfWeek;
  int startMinutes;
  int endMinutes;

  FreeSlot({
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
  });

  int get duration => endMinutes - startMinutes;

  @override
  String toString() =>
      'FreeSlot(day=$dayOfWeek, ${formatMinutes(startMinutes)}-${formatMinutes(endMinutes)}, ${duration}min)';
}

/// Returns true if two time ranges overlap.
/// Ranges are [s1, e1) and [s2, e2) — half-open intervals.
bool overlaps(int s1, int e1, int s2, int e2) {
  return s1 < e2 && s2 < e1;
}

/// Formats minutes-since-midnight into a human-readable string.
/// e.g., 600 → "10:00 AM", 810 → "1:30 PM"
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final displayM = m.toString().padLeft(2, '0');
  return '$displayH:$displayM $period';
}

/// Formats a duration in minutes to a human-readable string.
/// e.g., 150 → "2h 30m", 90 → "1h 30m", 45 → "45m"
String formatDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Converts hours + minutes to minutes-since-midnight.
/// e.g., timeToMinutes(10, 30) → 630
int timeToMinutes(int hour, int minute) => hour * 60 + minute;

/// Computes free slots between occupied blocks on a given day.
///
/// [occupied] must be sorted by startMinutes.
/// Returns slots with duration >= [minSlotMinutes].
List<FreeSlot> computeFreeSlots({
  required int dayOfWeek,
  required List<({int start, int end})> occupied,
  required int dayStart,
  required int dayEnd,
  required int minSlotMinutes,
}) {
  final slots = <FreeSlot>[];
  var cursor = dayStart;

  for (final block in occupied) {
    if (block.start > cursor) {
      final gap = block.start - cursor;
      if (gap >= minSlotMinutes) {
        slots.add(FreeSlot(
          dayOfWeek: dayOfWeek,
          startMinutes: cursor,
          endMinutes: block.start,
        ));
      }
    }
    if (block.end > cursor) {
      cursor = block.end;
    }
  }

  // Remaining time until end of day.
  if (dayEnd > cursor) {
    final gap = dayEnd - cursor;
    if (gap >= minSlotMinutes) {
      slots.add(FreeSlot(
        dayOfWeek: dayOfWeek,
        startMinutes: cursor,
        endMinutes: dayEnd,
      ));
    }
  }

  return slots;
}
