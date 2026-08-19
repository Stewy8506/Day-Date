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

  int dailyCapForDay(int day, bool isCollegeDay) {
    if (isCollegeDay) {
      return target.dailyCapMinutes;
    } else {
      // Scale up daily cap on weekends / free days by 1.5x (e.g., 3h -> 4.5h deep dive)
      return min(target.weeklyMinutes, (target.dailyCapMinutes * 1.5).round());
    }
  }

  int remainingForDay(int day, bool isCollegeDay) =>
      dailyCapForDay(day, isCollegeDay) - (dailyAllocatedMinutes[day] ?? 0);

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

      // Add Human Transition / Prep Buffers to occupied calculations:
      // 1. 30-min Lunch / Post-Commute Buffer after afternoon commute or Free Time
      // 2. 20-min Pre-Gym Prep Buffer before Gym
      for (final b in allOccupied[day]!) {
        if ((b.label == 'Commute' || b.label == 'Free Time') && b.startMinutes >= 570) {
          rawOccupied.add((
            start: b.endMinutes,
            end: min(kDayEndMinutes, b.endMinutes + 30),
          ));
        } else if (b.label.toLowerCase().contains('gym')) {
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
    }) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) return false;

      final isCollegeDay = isCollegeWeekday(day);
      if (alloc.remainingForDay(day, isCollegeDay) <= 0) return false;

      // Cognitive Load Guard: on college days, limit to max 2 distinct targets
      final currentTargets = dailyTargetIds[day]!;
      if (isCollegeDay &&
          !currentTargets.contains(target.id) &&
          currentTargets.length >= 2 &&
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
        if (slot.duration < kMinBlockMinutes) continue;
        if (alloc.isFilled) break;
        if (alloc.remainingForDay(day, isCollegeDay) <= 0) break;

        int needed = _calculateAllocation(
          remaining: alloc.remainingMinutes,
          dailyRemaining: alloc.remainingForDay(day, isCollegeDay),
          slotDuration: slot.duration,
          maxSessionMinutes: maxSessionMinutes,
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
        slot.startMinutes += needed;

        if (slot.duration < kMinBlockMinutes) {
          freeSlotsByDay[day]!.remove(slot);
        }
        return true;
      }
      return false;
    }

    // ── Pass 1: Weekend & Free-Day Deep Focus Allocation ──
    // Give Saturday and Sunday (and accelerated off days) uninterrupted 3.0h–4.5h blocks
    for (final target in sortedTargets) {
      for (int day = kMonday; day <= kSunday; day++) {
        if (!isWideOpenDay(day)) continue;

        final isCollegeDay = false;
        final weekendCap = allocations[target.id]!.dailyCapForDay(day, isCollegeDay);
        final deepBlockMinutes = min(
          weekendCap,
          max(kMinBlockMinutes * 2, (target.weeklyMinutes / 3).round()),
        );

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: true,
          maxSessionMinutes: deepBlockMinutes,
          allowNewTargetOnCollegeDay: true,
        );
      }
    }

    // ── Pass 2: Weekday Focused Allocation (Max 2 targets / day) ──
    for (final target in sortedTargets) {
      for (int day = kMonday; day <= kSunday; day++) {
        if (isWideOpenDay(day)) continue;

        final isCollegeDay = true;
        final targetCap = allocations[target.id]!.dailyCapForDay(day, isCollegeDay);

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: true,
          maxSessionMinutes: targetCap,
          allowNewTargetOnCollegeDay: false, // Enforce 2-target limit
        );
      }
    }

    // ── Pass 3: Fill Remaining Quotas in Preferred Affinity Windows ──
    bool madeProgress = true;
    while (madeProgress) {
      madeProgress = false;
      for (int day = kMonday; day <= kSunday; day++) {
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
      for (int day = kMonday; day <= kSunday; day++) {
        for (final target in sortedTargets) {
          if (tryAllocate(
            target: target,
            day: day,
            affinityOnly: false,
            allowNewTargetOnCollegeDay: true,
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
        // On weekends or for final top-up, allow slight cap flexibility (+60m) to hit 100%
        final effectiveDailyRem = isCollegeDay ? dailyRem : (dailyRem + 60);
        if (effectiveDailyRem <= 0) continue;

        final slots = freeSlotsByDay[day]!;
        for (final slot in List<FreeSlot>.from(slots)) {
          if (slot.startMinutes == block.endMinutes && slot.duration > 0) {
            final toAdd = min(remaining, min(effectiveDailyRem, slot.duration));
            if (toAdd > 0) {
              floatingBlocks[i] = block.copyWith(endMinutes: block.endMinutes + toAdd);
              alloc.allocate(day, toAdd);
              slot.startMinutes += toAdd;
              remaining -= toAdd;
              if (slot.duration < kMinBlockMinutes) {
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

  /// Calculates how many minutes to allocate from a slot, respecting
  /// the minimum block size, daily cap, weekly remaining, and optional session limit.
  static int _calculateAllocation({
    required int remaining,
    required int dailyRemaining,
    required int slotDuration,
    int? maxSessionMinutes,
  }) {
    int needed = remaining;
    if (maxSessionMinutes != null && needed > maxSessionMinutes) {
      needed = maxSessionMinutes;
    }
    if (needed > dailyRemaining) needed = dailyRemaining;
    if (needed > slotDuration) needed = slotDuration;

    // Prevent leaving tiny unreachable crumbs:
    final leftover = remaining - needed;
    if (leftover > 0 && leftover < kMinBlockMinutes) {
      final absorbAttempt = remaining;
      if (absorbAttempt <= dailyRemaining && absorbAttempt <= slotDuration) {
        needed = absorbAttempt;
      }
    }

    // Enforce minimum block size.
    if (needed < kMinBlockMinutes) {
      if (slotDuration >= kMinBlockMinutes &&
          dailyRemaining >= kMinBlockMinutes &&
          remaining >= kMinBlockMinutes &&
          (maxSessionMinutes == null || maxSessionMinutes >= kMinBlockMinutes)) {
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
