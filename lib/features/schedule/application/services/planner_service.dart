/// The core scheduling engine implementing the Bounded Interleaved Strategy.
///
/// Algorithm overview:
/// 1. Build occupied map from fixed blocks + deviations.
/// 2. Compute free slots per day (≥ 90 min).
/// 3. Tag free slots with time affinity windows.
/// 4. Multi-pass interleaved allocation with affinity bias + daily caps.
/// 5. Return full weekly schedule with allocation warnings.
library;

import 'dart:math';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/utils/time_utils.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:uuid/uuid.dart';

// ──────────────────────────────────────────────────────────
// Result types
// ──────────────────────────────────────────────────────────

/// Warning emitted when a target cannot fully fill its weekly quota.
class AllocationWarning {
  final String targetId;
  final String targetName;
  final double requestedHours;
  final double allocatedHours;
  final double shortfallHours;

  const AllocationWarning({
    required this.targetId,
    required this.targetName,
    required this.requestedHours,
    required this.allocatedHours,
    required this.shortfallHours,
  });

  @override
  String toString() =>
      'AllocationWarning($targetName: requested=${requestedHours}h, '
      'allocated=${allocatedHours}h, shortfall=${shortfallHours}h)';
}

/// The complete result of a schedule computation.
class ScheduleResult {
  /// All blocks for each day (1=Mon → 7=Sun), sorted by start time.
  final Map<int, List<TimeBlock>> dailySchedule;

  /// Warnings for targets that couldn't fill their quota.
  final List<AllocationWarning> warnings;

  /// Actual hours allocated per target ID.
  final Map<String, double> allocatedHours;

  const ScheduleResult({
    required this.dailySchedule,
    required this.warnings,
    required this.allocatedHours,
  });
}

// ──────────────────────────────────────────────────────────
// Internal tracking types
// ──────────────────────────────────────────────────────────

class _TargetAllocation {
  final TaskTarget target;
  int totalAllocatedMinutes = 0;
  final Map<int, int> dailyAllocatedMinutes = {};

  _TargetAllocation(this.target);

  int get remainingMinutes =>
      target.weeklyMinutes - totalAllocatedMinutes;

  int remainingForDay(int day) =>
      target.dailyCapMinutes - (dailyAllocatedMinutes[day] ?? 0);

  bool get isFilled => totalAllocatedMinutes >= target.weeklyMinutes;

  void allocate(int day, int minutes) {
    totalAllocatedMinutes += minutes;
    dailyAllocatedMinutes[day] =
        (dailyAllocatedMinutes[day] ?? 0) + minutes;
  }
}

// ──────────────────────────────────────────────────────────
// PlannerService
// ──────────────────────────────────────────────────────────

class PlannerService {
  static const _uuid = Uuid();

  /// Computes the full weekly schedule from raw inputs.
  ScheduleResult computeWeeklySchedule({
    required List<TimeBlock> fixedBlocks,
    required List<ScheduleDeviation> deviations,
    required List<TaskTarget> targets,
  }) {
    // ── Step 1: Build occupied map ───────────────────────

    // Deep copy fixed blocks so we can mutate for extensions.
    final allOccupied = <int, List<TimeBlock>>{};
    for (int day = kMonday; day <= kSunday; day++) {
      allOccupied[day] = [];
    }

    // Identify college-off days from collegeCancellation deviations.
    final collegeOffDays = <int, OffDayStrategy>{};
    for (final dev in deviations) {
      if (dev.type == DeviationType.collegeCancellation) {
        collegeOffDays[dev.dayOfWeek] =
            dev.offDayStrategy ?? OffDayStrategy.accelerateWeek;
      }
    }

    // Add fixed blocks — skip College+Commute on college-off days.
    for (final block in fixedBlocks) {
      if (collegeOffDays.containsKey(block.dayOfWeek) &&
          (block.label == 'College' || block.label == 'Commute')) {
        continue; // College cancelled — don't add to occupied map.
      }
      allOccupied[block.dayOfWeek]!.add(block);
    }

    // For restAndLeisure days, insert a "Free Time" block spanning
    // the college+commute range to prevent floating allocation.
    for (final entry in collegeOffDays.entries) {
      if (entry.value == OffDayStrategy.restAndLeisure) {
        final dayCollegeBlocks = fixedBlocks.where((b) =>
            b.dayOfWeek == entry.key &&
            (b.label == 'College' || b.label == 'Commute'));
        if (dayCollegeBlocks.isNotEmpty) {
          final earliest =
              dayCollegeBlocks.map((b) => b.startMinutes).reduce(min);
          final latest =
              dayCollegeBlocks.map((b) => b.endMinutes).reduce(max);
          allOccupied[entry.key]!.add(TimeBlock(
            id: 'free-time-${entry.key}',
            label: 'Free Time',
            dayOfWeek: entry.key,
            startMinutes: earliest,
            endMinutes: latest,
            type: TimeBlockType.deviation,
          ));
        }
      }
    }

    // Apply remaining deviations (blockout + extension).
    for (final dev in deviations) {
      if (dev.type == DeviationType.blockout) {
        // Add blockout as an occupied range.
        allOccupied[dev.dayOfWeek]!.add(TimeBlock(
          id: dev.id,
          label: dev.label,
          dayOfWeek: dev.dayOfWeek,
          startMinutes: dev.startMinutes,
          endMinutes: dev.endMinutes,
          type: TimeBlockType.deviation,
        ));
      } else if (dev.type == DeviationType.extension &&
          dev.extendsBlockId != null &&
          dev.extensionMinutes != null) {
        // Find and extend the referenced block.
        final dayBlocks = allOccupied[dev.dayOfWeek]!;
        for (int i = 0; i < dayBlocks.length; i++) {
          if (dayBlocks[i].id == dev.extendsBlockId) {
            final original = dayBlocks[i];
            dayBlocks[i] = original.copyWith(
              endMinutes: original.endMinutes + dev.extensionMinutes!,
            );

            // Also shift the commute block that follows (if any).
            for (int j = 0; j < dayBlocks.length; j++) {
              if (dayBlocks[j].label == 'Commute' &&
                  dayBlocks[j].startMinutes == original.endMinutes) {
                final commute = dayBlocks[j];
                dayBlocks[j] = commute.copyWith(
                  startMinutes:
                      commute.startMinutes + dev.extensionMinutes!,
                  endMinutes: commute.endMinutes + dev.extensionMinutes!,
                );
                break;
              }
            }
            break;
          }
        }
      }
      // collegeCancellation deviations are already handled above.
    }

    // Sort each day's occupied blocks by start time.
    for (final day in allOccupied.keys) {
      allOccupied[day]!
          .sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    // ── Step 2: Compute free slots ───────────────────────

    final freeSlotsByDay = <int, List<FreeSlot>>{};
    for (int day = kMonday; day <= kSunday; day++) {
      // Merge overlapping occupied ranges before computing free slots.
      final rawOccupied = allOccupied[day]!
          .map((b) => (start: b.startMinutes, end: b.endMinutes))
          .toList();
      final mergedOccupied = _mergeRanges(rawOccupied);

      freeSlotsByDay[day] = computeFreeSlots(
        dayOfWeek: day,
        occupied: mergedOccupied,
        dayStart: kDayStartMinutes,
        dayEnd: kDayEndMinutes,
        minSlotMinutes: kMinBlockMinutes,
      );
    }

    // ── Step 3: Bounded Interleaved Allocation ───────────

    // Sort targets by priority.
    final sortedTargets = List<TaskTarget>.from(targets)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final allocations = {
      for (final t in sortedTargets) t.id: _TargetAllocation(t),
    };

    final floatingBlocks = <TimeBlock>[];

    // Multi-pass: repeat until no more progress can be made.
    bool madeProgress = true;
    while (madeProgress) {
      madeProgress = false;

      for (int day = kMonday; day <= kSunday; day++) {
        for (final target in sortedTargets) {
          final alloc = allocations[target.id]!;
          if (alloc.isFilled) continue;
          if (alloc.remainingForDay(day) <= 0) continue;

          final slots = freeSlotsByDay[day]!;
          if (slots.isEmpty) continue;

          // Affinity pass: try preferred-window slots first.
          final affinitySlots = _getAffinitySlots(slots, target.affinity);
          final spilloverSlots = slots
              .where((s) => !affinitySlots.contains(s))
              .toList();

          // Try affinity slots first, then spillover.
          final orderedSlots = [...affinitySlots, ...spilloverSlots];

          for (final slot in orderedSlots) {
            if (slot.duration < kMinBlockMinutes) continue;
            if (alloc.isFilled) break;
            if (alloc.remainingForDay(day) <= 0) break;

            int needed = _calculateAllocation(
              remaining: alloc.remainingMinutes,
              dailyRemaining: alloc.remainingForDay(day),
              slotDuration: slot.duration,
            );

            if (needed <= 0) continue;

            // Create the floating block.
            floatingBlocks.add(TimeBlock(
              id: _uuid.v4(),
              label: target.name,
              dayOfWeek: day,
              startMinutes: slot.startMinutes,
              endMinutes: slot.startMinutes + needed,
              type: TimeBlockType.floating,
              parentTargetId: target.id,
            ));

            alloc.allocate(day, needed);
            slot.startMinutes += needed;
            madeProgress = true;

            // Remove slot if fully consumed or too small.
            if (slot.duration < kMinBlockMinutes) {
              freeSlotsByDay[day]!.remove(slot);
            }
          }
        }
      }
    }

    // ── Step 4: Build result ─────────────────────────────

    final dailySchedule = <int, List<TimeBlock>>{};
    for (int day = kMonday; day <= kSunday; day++) {
      final dayBlocks = <TimeBlock>[
        ...allOccupied[day]!,
        ...floatingBlocks.where((b) => b.dayOfWeek == day),
      ];
      dayBlocks.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      dailySchedule[day] = dayBlocks;
    }

    // Build warnings.
    final warnings = <AllocationWarning>[];
    final allocatedHoursMap = <String, double>{};

    for (final entry in allocations.entries) {
      final alloc = entry.value;
      final allocated = alloc.totalAllocatedMinutes / 60.0;
      allocatedHoursMap[entry.key] = allocated;

      if (!alloc.isFilled) {
        warnings.add(AllocationWarning(
          targetId: alloc.target.id,
          targetName: alloc.target.name,
          requestedHours: alloc.target.weeklyHours,
          allocatedHours: allocated,
          shortfallHours: alloc.target.weeklyHours - allocated,
        ));
      }
    }

    return ScheduleResult(
      dailySchedule: dailySchedule,
      warnings: warnings,
      allocatedHours: allocatedHoursMap,
    );
  }

  /// Returns slots that overlap with the given affinity window.
  static List<FreeSlot> _getAffinitySlots(
    List<FreeSlot> slots,
    TimeAffinity affinity,
  ) {
    if (affinity == TimeAffinity.flexible) return List.from(slots);

    final (windowStart, windowEnd) = _affinityWindow(affinity);

    return slots
        .where(
            (s) => overlaps(s.startMinutes, s.endMinutes, windowStart, windowEnd))
        .toList();
  }

  /// Returns the (start, end) minutes for a given affinity.
  static (int, int) _affinityWindow(TimeAffinity affinity) {
    switch (affinity) {
      case TimeAffinity.morning:
        return (kMorningStart, kMorningEnd);
      case TimeAffinity.afternoon:
        return (kAfternoonStart, kAfternoonEnd);
      case TimeAffinity.lateNight:
        return (kLateNightStart, kLateNightEnd);
      case TimeAffinity.flexible:
        return (kDayStartMinutes, kDayEndMinutes);
    }
  }

  /// Calculates how many minutes to allocate from a slot, respecting
  /// the minimum block size, daily cap, and weekly remaining.
  static int _calculateAllocation({
    required int remaining,
    required int dailyRemaining,
    required int slotDuration,
  }) {
    // How much we'd ideally allocate.
    int needed = remaining;
    if (needed > dailyRemaining) needed = dailyRemaining;
    if (needed > slotDuration) needed = slotDuration;

    // Enforce minimum block size.
    if (needed < kMinBlockMinutes) {
      if (slotDuration >= kMinBlockMinutes &&
          dailyRemaining >= kMinBlockMinutes &&
          remaining >= kMinBlockMinutes) {
        needed = kMinBlockMinutes;
      } else {
        return 0; // Can't fit a valid block.
      }
    }

    return needed;
  }

  /// Merges overlapping or adjacent time ranges into non-overlapping ranges.
  /// Input must be sorted by start time.
  static List<({int start, int end})> _mergeRanges(
    List<({int start, int end})> ranges,
  ) {
    if (ranges.isEmpty) return [];

    final sorted = List<({int start, int end})>.from(ranges)
      ..sort((a, b) => a.start.compareTo(b.start));

    final merged = <({int start, int end})>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.last;

      if (current.start <= last.end) {
        // Overlapping or adjacent — extend the last merged range.
        merged[merged.length - 1] = (
          start: last.start,
          end: current.end > last.end ? current.end : last.end,
        );
      } else {
        merged.add(current);
      }
    }

    return merged;
  }
}
