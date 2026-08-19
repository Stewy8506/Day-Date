/// The core scheduling engine implementing the Bounded Interleaved Strategy.
///
/// Enhanced with:
/// - 30-minute Post-College Commute & Lunch Buffer
/// - 20-minute Pre-Gym Preparation Buffer
/// - Weekday Cognitive Focus Limit (max 2 floating targets per college day)
/// - Weekend & Non-College Deep Focus Session Scaling (up to 4.5h uninterrupted blocks)
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

  int get remainingMinutes => target.weeklyMinutes - totalAllocatedMinutes;

  int dailyCapForDay(int day, bool isCollegeDay) => target.weeklyMinutes;

  int remainingForDay(int day, bool isCollegeDay) => remainingMinutes;

  bool get isFilled => totalAllocatedMinutes >= target.weeklyMinutes;

  void allocate(int day, int minutes) {
    totalAllocatedMinutes += minutes;
    dailyAllocatedMinutes[day] = (dailyAllocatedMinutes[day] ?? 0) + minutes;
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
      final labelLower = block.label.toLowerCase();
      if (collegeOffDays.containsKey(block.dayOfWeek) &&
          (labelLower.contains('college') || labelLower.contains('commute'))) {
        continue; // College cancelled — don't add to occupied map.
      }
      allOccupied[block.dayOfWeek]!.add(block);
    }

    // For restAndLeisure days, insert a "Free Time" block spanning
    // the college+commute range to prevent floating allocation.
    for (final entry in collegeOffDays.entries) {
      if (entry.value == OffDayStrategy.restAndLeisure) {
        final dayCollegeBlocks = fixedBlocks.where((b) {
          final labelLower = b.label.toLowerCase();
          return b.dayOfWeek == entry.key &&
              (labelLower.contains('college') || labelLower.contains('commute'));
        });
        if (dayCollegeBlocks.isNotEmpty) {
          final earliest =
              dayCollegeBlocks.map((b) => b.startMinutes).reduce(min);
          final latest = dayCollegeBlocks.map((b) => b.endMinutes).reduce(max);
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

    // Apply custom deviations (blockout + extension).
    for (final dev in deviations) {
      if (dev.type == DeviationType.blockout) {
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
        final dayBlocks = allOccupied[dev.dayOfWeek]!;
        for (int i = 0; i < dayBlocks.length; i++) {
          if (dayBlocks[i].id == dev.extendsBlockId) {
            final original = dayBlocks[i];
            dayBlocks[i] = original.copyWith(
              endMinutes: original.endMinutes + dev.extensionMinutes!,
            );

            // Shift subsequent commute block if any.
            for (int j = 0; j < dayBlocks.length; j++) {
              if (dayBlocks[j].label == 'Commute' &&
                  dayBlocks[j].startMinutes == original.endMinutes) {
                final commute = dayBlocks[j];
                dayBlocks[j] = commute.copyWith(
                  startMinutes: commute.startMinutes + dev.extensionMinutes!,
                  endMinutes: commute.endMinutes + dev.extensionMinutes!,
                );
                break;
              }
            }
            break;
          }
        }
      }
    }

    // Sort each day's occupied blocks by start time.
    for (final day in allOccupied.keys) {
      allOccupied[day]!.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    // ── Step 2: Compute free slots with Transition Buffers ──

    final freeSlotsByDay = <int, List<FreeSlot>>{};
    for (int day = kMonday; day <= kSunday; day++) {
      final isWeekend = (day == kSaturday || day == kSunday);
      final dayStart = isWeekend ? kWeekendStartMinutes : kWeekdayStartMinutes;

      final rawOccupied = allOccupied[day]!
          .map((b) => (start: b.startMinutes, end: b.endMinutes))
          .toList();

      // 3. Home Day Lunch & Rest Window: 2:00 PM – 3:30 PM (840 to 930 min)
      // Applies to weekends and any weekday where college is off/cancelled!
      final isNonCollegeDay = isWeekend || collegeOffDays.containsKey(day);
      if (isNonCollegeDay) {
        rawOccupied.add((start: 840, end: 930));
      }

      for (final b in allOccupied[day]!) {
        final labelLower = b.label.toLowerCase();
        if ((labelLower.contains('commute') || labelLower.contains('college') || b.label == 'Free Time') && b.startMinutes >= 570) {
          rawOccupied.add((
            start: b.endMinutes,
            end: min(kDayEndMinutes, b.endMinutes + 30),
          ));
        } else if (labelLower.contains('gym')) {
          rawOccupied.add((
            start: max(dayStart, b.startMinutes - 20),
            end: b.startMinutes,
          ));
        }
      }

      final mergedOccupied = _mergeRanges(rawOccupied);

      freeSlotsByDay[day] = computeFreeSlots(
        dayOfWeek: day,
        occupied: mergedOccupied,
        dayStart: dayStart,
        dayEnd: kDayEndMinutes,
        minSlotMinutes: kMinBlockMinutes,
      );
    }

    // ── Step 3: Bounded Interleaved Allocation ───────────

    final sortedTargets = List<TaskTarget>.from(targets)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final allocations = {
      for (final t in sortedTargets) t.id: _TargetAllocation(t),
    };

    final floatingBlocks = <TimeBlock>[];
    final dailyTargetIds = <int, Set<String>>{
      for (int day = kMonday; day <= kSunday; day++) day: <String>{},
    };

    final dailyFloatingMinutes = <int, int>{
      for (int day = kMonday; day <= kSunday; day++) day: 0,
    };

    final dayFixedMinutes = <int, int>{
      for (int day = kMonday; day <= kSunday; day++)
        day: allOccupied[day]!.fold(0, (sum, b) => sum + b.durationMinutes),
    };

    // Helper: determine if a day is treated as a regular college weekday
    // (True for Mon-Fri unless marked with accelerateWeek strategy)
    bool isCollegeWeekday(int day) {
      if (day == kSaturday || day == kSunday) return false;
      if (collegeOffDays[day] == OffDayStrategy.accelerateWeek) return false;
      return true;
    }

    // Helper: determine if a day is a wide open day (Saturday, Sunday, or accelerated college-off day)
    bool isWideOpenDay(int day) => !isCollegeWeekday(day);

    // Helper to attempt allocating a chunk to a specific target on a specific day
    bool tryAllocate({
      required TaskTarget target,
      required int day,
      required bool affinityOnly,
      int? maxSessionMinutes,
      bool allowNewTargetOnCollegeDay = true,
      bool enforceDailyExertionCap = true,
    }) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) return false;

      final isCollegeDay = isCollegeWeekday(day);
      if (alloc.remainingForDay(day, isCollegeDay) <= 0) return false;

      // Cognitive Load Guard: on college days, allow up to 3 distinct targets (Morning, Afternoon, Late Night)
      final currentTargets = dailyTargetIds[day]!;
      if (isCollegeDay &&
          !currentTargets.contains(target.id) &&
          currentTargets.length >= 3 &&
          !allowNewTargetOnCollegeDay) {
        return false;
      }

      final slots = freeSlotsByDay[day]!;
      if (slots.isEmpty) return false;

      final affinitySlots = _getAffinitySlots(slots, target.affinity, day);
      final candidateSlots = affinityOnly
          ? affinitySlots
          : [...affinitySlots, ...slots.where((s) => !affinitySlots.contains(s))];

      for (final slot in candidateSlots) {
        if (slot.duration <= 0) continue;
        if (alloc.isFilled) break;
        if (alloc.remainingForDay(day, isCollegeDay) <= 0) break;

        int needed = _calculateAllocation(
          remaining: alloc.remainingMinutes,
          dailyRemaining: alloc.remainingForDay(day, isCollegeDay),
          slotDuration: slot.duration,
          maxSessionMinutes: maxSessionMinutes != null ? min(maxSessionMinutes, 270) : 270,
        );

        if (needed < kMinBlockMinutes) continue;

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
        dailyTargetIds[day]!.add(target.id);
        dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + needed;

        // Insert inter-session rest buffer between consecutive focus activities
        final isWeekend = day == kSaturday || day == kSunday;
        final interSessionBreak = isWeekend
            ? kWeekendInterSessionBreakMinutes
            : kWeekdayInterSessionBreakMinutes;
        slot.startMinutes += needed + interSessionBreak;

        if (slot.duration <= 0) {
          freeSlotsByDay[day]!.remove(slot);
        }
        return true;
      }
      return false;
    }

    // ── Pass 1: Weekend & Free-Day Deep Focus Allocation ──
    // Allocates primary deep blocks on Saturday and Sunday (e.g. CAT 11 AM - 2 PM, SWE afternoon).
    // This diverts morning study pressure away from hectic weekdays to relaxed weekends.
    final weekendTargets = List<TaskTarget>.from(sortedTargets)
      ..sort((a, b) {
        final orderA = _affinityOrder(a.affinity);
        final orderB = _affinityOrder(b.affinity);
        if (orderA != orderB) return orderA.compareTo(orderB);
        return a.priority.compareTo(b.priority);
      });

    for (final target in weekendTargets) {
      for (int day = kMonday; day <= kSunday; day++) {
        if (!isWideOpenDay(day)) continue;

        final alloc = allocations[target.id]!;
        if (alloc.isFilled) continue;

        final weekendCap = (target.dailyCapMinutes * 1.5).round();
        final deepBlockMinutes = min(
          alloc.remainingMinutes,
          min(weekendCap, max(kMinBlockMinutes * 2, (target.weeklyMinutes / 3).round())),
        );

        if (deepBlockMinutes < kMinBlockMinutes) continue;

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: true,
          maxSessionMinutes: min(deepBlockMinutes, 270),
          allowNewTargetOnCollegeDay: true,
        );
      }
    }

    // ── Pass 2: Weekday Focused Allocation (3 Phase Days: Morning, Afternoon, Late-Night) ──
    // Fills remaining quotas in light weekday morning (CAT/ECE), afternoon (SWE), and late-night (Freelancing) slots.
    for (final target in sortedTargets) {
      final days = List<int>.generate(7, (i) => i + 1)
        ..sort((a, b) => (dayFixedMinutes[a]! + dailyFloatingMinutes[a]!)
            .compareTo(dayFixedMinutes[b]! + dailyFloatingMinutes[b]!));

      for (final day in days) {
        if (isWideOpenDay(day)) continue;

        final sessionCap = target.affinity == TimeAffinity.morning
            ? 120
            : (target.affinity == TimeAffinity.lateNight ? 120 : 180);

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: true,
          maxSessionMinutes: sessionCap,
          allowNewTargetOnCollegeDay: false, // Enforce 3-target limit
        );
      }
    }

    // ── Pass 3: Fill Remaining Quotas in Preferred Affinity Windows ──
    bool madeProgress = true;
    while (madeProgress) {
      madeProgress = false;
      final days = List<int>.generate(7, (i) => i + 1)
        ..sort((a, b) => (dayFixedMinutes[a]! + dailyFloatingMinutes[a]!)
            .compareTo(dayFixedMinutes[b]! + dailyFloatingMinutes[b]!));

      for (final day in days) {
        for (final target in sortedTargets) {
          if (tryAllocate(
            target: target,
            day: day,
            affinityOnly: true,
            allowNewTargetOnCollegeDay: true,
          )) {
            madeProgress = true;
          }
        }
      }
    }

    // ── Pass 4: Flexible Spillover for any Remaining Minutes ──
    madeProgress = true;
    while (madeProgress) {
      madeProgress = false;
      final days = List<int>.generate(7, (i) => i + 1)
        ..sort((a, b) => (dayFixedMinutes[a]! + dailyFloatingMinutes[a]!)
            .compareTo(dayFixedMinutes[b]! + dailyFloatingMinutes[b]!));

      for (final day in days) {
        for (final target in sortedTargets) {
          if (tryAllocate(
            target: target,
            day: day,
            affinityOnly: false,
            allowNewTargetOnCollegeDay: true,
            enforceDailyExertionCap: true,
          )) {
            madeProgress = true;
          }
        }
      }
    }

    // ── Pass 5: Top-Up Remaining Minutes into Existing Adjacent Blocks ──
    // Extends existing blocks to absorb remaining quota without creating sub-90m blocks.
    for (final target in sortedTargets) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) continue;

      var remaining = alloc.remainingMinutes;
      if (remaining <= 0) continue;

      for (int i = 0; i < floatingBlocks.length; i++) {
        final block = floatingBlocks[i];
        if (block.parentTargetId != target.id) continue;

        final day = block.dayOfWeek;
        final isCollegeDay = isCollegeWeekday(day);
        final dailyRem = alloc.remainingForDay(day, isCollegeDay);
        if (dailyRem <= 0) continue;

        final isWeekend = day == kSaturday || day == kSunday;
        final interSessionBreak = isWeekend
            ? kWeekendInterSessionBreakMinutes
            : kWeekdayInterSessionBreakMinutes;

        final slots = freeSlotsByDay[day]!;
        for (final slot in List<FreeSlot>.from(slots)) {
          final gap = slot.startMinutes - block.endMinutes;
          if (gap >= 0 && gap <= interSessionBreak + slot.duration) {
            final availableToAdd = gap + slot.duration;
            final toAdd = min(remaining, availableToAdd);
            if (toAdd > 0) {
              floatingBlocks[i] = block.copyWith(endMinutes: block.endMinutes + toAdd);
              alloc.allocate(day, toAdd);
              dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + toAdd;
              final consumedFromSlot = max(0, toAdd - gap);
              slot.startMinutes += consumedFromSlot;
              remaining -= toAdd;
              if (slot.duration <= 0) {
                slots.remove(slot);
              }
              break;
            }
          }
        }

        if (alloc.isFilled) break;
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
  /// On weekends, late-night tasks (like Freelancing) are flexible across afternoon and night.
  static List<FreeSlot> _getAffinitySlots(
    List<FreeSlot> slots,
    TimeAffinity affinity,
    int day,
  ) {
    if (affinity == TimeAffinity.flexible) return List.from(slots);
    if ((day == kSaturday || day == kSunday) && affinity == TimeAffinity.lateNight) {
      return List.from(slots);
    }

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

  /// Returns chronological sorting rank for time affinity.
  static int _affinityOrder(TimeAffinity affinity) {
    switch (affinity) {
      case TimeAffinity.morning:
        return 1;
      case TimeAffinity.afternoon:
        return 2;
      case TimeAffinity.flexible:
        return 3;
      case TimeAffinity.lateNight:
        return 4;
    }
  }

  /// Calculates how many minutes to allocate from a slot, respecting
  /// the minimum block size, daily cap, weekly remaining, and optional session limit.
  static int _calculateAllocation({
    required int remaining,
    required int dailyRemaining,
    required int slotDuration,
    int? maxSessionMinutes,
  }) {
    if (remaining <= 0) return 0;

    int needed = remaining;
    if (maxSessionMinutes != null && needed > maxSessionMinutes) {
      needed = maxSessionMinutes;
    }
    if (needed > dailyRemaining) needed = dailyRemaining;
    if (needed > slotDuration) needed = slotDuration;

    // Never exceed the target's total remaining quota.
    if (needed > remaining) {
      needed = remaining;
    }

    // Lookahead crumb-prevention:
    // If allocating `needed` would leave a remainder `leftover` that is between 1 and 89 minutes:
    final leftover = remaining - needed;
    if (leftover > 0 && leftover < kMinBlockMinutes) {
      // Option A: If today's slot + dailyCap can absorb the leftover, absorb it today.
      if (remaining <= dailyRemaining && remaining <= slotDuration &&
          (maxSessionMinutes == null || remaining <= maxSessionMinutes + 30)) {
        needed = remaining;
      } else {
        // Option B: Reduce today's allocation so the leftover is >= kMinBlockMinutes (90m),
        // allowing another day to schedule a valid 90m session.
        final adjusted = needed - (kMinBlockMinutes - leftover);
        if (adjusted >= kMinBlockMinutes) {
          needed = adjusted;
        }
      }
    }

    // Enforce minimum block size for standalone blocks.
    if (needed < kMinBlockMinutes) {
      return 0; // Can't fit a valid block.
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
