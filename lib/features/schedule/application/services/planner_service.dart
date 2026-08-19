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

  int dailyCapForDay(
    int day,
    bool isCollegeDay, {
    bool ignoreCapOnFreeDays = false,
    bool isUnderPressure = false,
  }) {
    final isFreeDay = !isCollegeDay;
    if (isFreeDay && (ignoreCapOnFreeDays || day == kSaturday || day == kSunday)) {
      return 1440; // Lift daily cap on free days (weekends & college-off) to absorb full spillover
    }
    if (isCollegeDay) {
      final baseCap = max(kMinBlockMinutes, target.dailyCapMinutes);
      return isUnderPressure ? (baseCap * 1.3).round() : baseCap;
    }
    // On Sunday / standard free days, morning sessions run up to 300m (5h) until lunch
    final freeDayCap = target.affinity == TimeAffinity.morning ? 300 : 270;
    final base = max(
      target.dailyCapMinutes,
      min(
        freeDayCap,
        max((target.dailyCapMinutes * 1.5).round(), (target.weeklyMinutes / 3).round()),
      ),
    );
    return isUnderPressure ? min(1440, (base * 1.3).round()) : base;
  }

  int remainingForDay(
    int day,
    bool isCollegeDay, {
    bool ignoreCapOnFreeDays = false,
    bool isUnderPressure = false,
  }) {
    final cap = dailyCapForDay(
      day,
      isCollegeDay,
      ignoreCapOnFreeDays: ignoreCapOnFreeDays,
      isUnderPressure: isUnderPressure,
    );
    final allocatedToday = dailyAllocatedMinutes[day] ?? 0;
    return max(0, min(remainingMinutes, cap - allocatedToday));
  }

  bool get isFilled => totalAllocatedMinutes >= target.weeklyMinutes;

  void allocate(int day, int minutes) {
    totalAllocatedMinutes += minutes;
    dailyAllocatedMinutes[day] = (dailyAllocatedMinutes[day] ?? 0) + minutes;
  }
}

/// User-configurable lunch & rest window settings.
class LunchWindowSettings {
  final bool isEnabled;
  final int startMinutes;
  final int endMinutes;

  const LunchWindowSettings({
    this.isEnabled = true,
    this.startMinutes = 840, // 2:00 PM (14:00)
    this.endMinutes = 930,   // 3:30 PM (15:30)
  });

  int get durationMinutes => endMinutes - startMinutes;
}

// ──────────────────────────────────────────────────────────
// PlannerService
// ──────────────────────────────────────────────────────────

class PlannerService {
  /// Computes the full weekly schedule from raw inputs.
  ScheduleResult computeWeeklySchedule({
    required List<TimeBlock> fixedBlocks,
    required List<ScheduleDeviation> deviations,
    required List<TaskTarget> targets,
    LunchWindowSettings lunchSettings = const LunchWindowSettings(),
    bool ignoreDailyCapOnFreeDays = false,
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
              (labelLower.contains('college') ||
                  labelLower.contains('commute'));
        });
        if (dayCollegeBlocks.isNotEmpty) {
          final earliest = dayCollegeBlocks
              .map((b) => b.startMinutes)
              .reduce(min);
          final latest = dayCollegeBlocks.map((b) => b.endMinutes).reduce(max);
          allOccupied[entry.key]!.add(
            TimeBlock(
              id: 'free-time-${entry.key}',
              label: 'Free Time',
              dayOfWeek: entry.key,
              startMinutes: earliest,
              endMinutes: latest,
              type: TimeBlockType.deviation,
            ),
          );
        }
      }
    }

    // Apply custom deviations (blockout + extension).
    for (final dev in deviations) {
      if (dev.type == DeviationType.blockout) {
        allOccupied[dev.dayOfWeek]!.add(
          TimeBlock(
            id: dev.id,
            label: dev.label,
            dayOfWeek: dev.dayOfWeek,
            startMinutes: dev.startMinutes,
            endMinutes: dev.endMinutes,
            type: TimeBlockType.deviation,
          ),
        );
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
      allOccupied[day]!.sort(
        (a, b) => a.startMinutes.compareTo(b.startMinutes),
      );
    }

    // ── Phase 0: Pressure Detection ──────────────────────
    final totalDemandMinutes = targets.fold(0, (s, t) => s + t.weeklyMinutes);

    int rawFreeCapacity = 0;
    for (int day = kMonday; day <= kSunday; day++) {
      final isWeekend = (day == kSaturday || day == kSunday);
      final isCollegeOff = collegeOffDays.containsKey(day);
      final dayStart = isWeekend
          ? kWeekendStartMinutes
          : (isCollegeOff ? kCollegeOffStartMinutes : kWeekdayStartMinutes);
      final dayFixed = allOccupied[day]!.fold(0, (sum, b) => sum + b.durationMinutes);
      final totalDayDuration = kDayEndMinutes - dayStart;
      rawFreeCapacity += max(0, totalDayDuration - dayFixed);
    }

    final isUnderPressure = totalDemandMinutes > 0 &&
        (totalDemandMinutes / rawFreeCapacity.clamp(1, 99999) > 0.70 ||
            deviations.any((d) => d.type == DeviationType.blockout));

    // ── Step 2: Compute free slots with Transition Buffers ──

    final freeSlotsByDay = <int, List<FreeSlot>>{};
    for (int day = kMonday; day <= kSunday; day++) {
      final isWeekend = (day == kSaturday || day == kSunday);
      final isCollegeOff = collegeOffDays.containsKey(day);
      final dayStart = isWeekend
          ? kWeekendStartMinutes
          : (isCollegeOff ? kCollegeOffStartMinutes : kWeekdayStartMinutes);

      final rawOccupied = allOccupied[day]!
          .map((b) => (start: b.startMinutes, end: b.endMinutes))
          .toList();

      // Configurable Lunch & Rest Window on weekends and college-off days
      final isNonCollegeDay = isWeekend || collegeOffDays.containsKey(day);
      if (isNonCollegeDay && lunchSettings.isEnabled && lunchSettings.durationMinutes > 0) {
        final effectiveLunchDuration = isUnderPressure
            ? min(lunchSettings.durationMinutes, kPressureLunchMinutes)
            : lunchSettings.durationMinutes;
        final lunchCenter = (lunchSettings.startMinutes + lunchSettings.endMinutes) ~/ 2;
        rawOccupied.add((
          start: lunchCenter - effectiveLunchDuration ~/ 2,
          end: lunchCenter + effectiveLunchDuration ~/ 2,
        ));
      }

      for (final b in allOccupied[day]!) {
        final labelLower = b.label.toLowerCase();
        if (labelLower.contains('commute') ||
            labelLower.contains('college') ||
            b.label == 'Free Time') {
          // Mandatory 20-min pre-college departure buffer
          if (b.startMinutes >= dayStart) {
            rawOccupied.add((
              start: max(dayStart, b.startMinutes - kPreCollegeBufferMinutes),
              end: b.startMinutes,
            ));
          }
          // Post-college return & unwind buffer (30 min)
          rawOccupied.add((
            start: b.endMinutes,
            end: min(kDayEndMinutes, b.endMinutes + kPostCollegeBufferMinutes),
          ));
        } else if (labelLower.contains('gym')) {
          // Mandatory 20-min pre-gym buffer
          rawOccupied.add((
            start: max(dayStart, b.startMinutes - kPreGymBufferMinutes),
            end: b.startMinutes,
          ));
          // Mandatory 30-min post-gym cooldown & dinner buffer
          rawOccupied.add((
            start: b.endMinutes,
            end: min(kDayEndMinutes, b.endMinutes + kPostGymBufferMinutes),
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

    // ── Prior-Day Baseline Lock for Causal Invariance ──
    // If deviations or college cancellations occur mid-week (e.g. Wednesday),
    // lock in baseline allocations for all prior days (Monday, Tuesday) so prior days never change!
    int minDevDay = kSunday + 1;
    for (final dev in deviations) {
      if (dev.dayOfWeek < minDevDay) {
        minDevDay = dev.dayOfWeek;
      }
    }

    if (deviations.isNotEmpty && minDevDay > kMonday && minDevDay <= kSunday) {
      final baseline = computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day < minDevDay; day++) {
        final dayFloating = baseline.dailySchedule[day]!
            .where((b) => b.type == TimeBlockType.floating)
            .toList();

        for (final block in dayFloating) {
          if (block.parentTargetId != null && allocations.containsKey(block.parentTargetId)) {
            floatingBlocks.add(block);
            allocations[block.parentTargetId]!.allocate(day, block.durationMinutes);
            dailyTargetIds[day]!.add(block.parentTargetId!);
            dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + block.durationMinutes;
          }
        }
        // Free slots for prior days are already consumed by baseline blocks
        freeSlotsByDay[day]!.clear();
      }
    }

    // Helper: determine if a day is treated as a regular college weekday
    // (True for Mon-Fri unless marked with accelerateWeek strategy)
    bool isCollegeWeekday(int day) {
      if (day == kSaturday || day == kSunday) return false;
      if (collegeOffDays[day] == OffDayStrategy.accelerateWeek) return false;
      return true;
    }

    // Helper: determine if a day is a wide open day (Saturday, Sunday, or accelerated college-off day)
    bool isWideOpenDay(int day) => !isCollegeWeekday(day);

    // Helper: find the start time of the first fixed block (e.g. College) on a given day
    int getFirstFixedBlockStart(int day) {
      final fixed = allOccupied[day]!.where((b) => b.type == TimeBlockType.fixed);
      if (fixed.isEmpty) return kDayEndMinutes;
      return fixed.map((b) => b.startMinutes).reduce(min);
    }

    // Helper to attempt allocating a chunk to a specific target on a specific day
    bool tryAllocate({
      required TaskTarget target,
      required int day,
      required bool affinityOnly,
      bool affinityPreferred = true,
      int? maxSessionMinutes,
      bool allowNewTargetOnCollegeDay = true,
      bool enforceDailyExertionCap = true,
      bool allowMultipleSessionsPerDay = false,
      bool allowFinalTail = false,
    }) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) return false;

      // Prevent splintering the same target into multiple short blocks on the same day during primary passes
      if (!allowMultipleSessionsPerDay && dailyTargetIds[day]!.contains(target.id)) {
        return false;
      }

      final isCollegeDay = isCollegeWeekday(day);
      if (alloc.remainingForDay(
            day,
            isCollegeDay,
            ignoreCapOnFreeDays: ignoreDailyCapOnFreeDays,
            isUnderPressure: isUnderPressure,
          ) <=
          0) {
        return false;
      }

      final firstFixedStart = isCollegeDay ? getFirstFixedBlockStart(day) : kDayEndMinutes;

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
      // Prioritize longest uninterrupted slot so we schedule deep continuous sessions
      final sortedAffinity = List<FreeSlot>.from(affinitySlots)
        ..sort((a, b) => b.duration.compareTo(a.duration));
      final nonAffinity = slots.where((s) => !affinitySlots.contains(s)).toList()
        ..sort((a, b) => b.duration.compareTo(a.duration));

      final candidateSlots = affinityOnly
          ? sortedAffinity
          : (affinityPreferred ? [...sortedAffinity, ...nonAffinity] : slots);

      for (final slot in candidateSlots) {
        if (slot.duration <= 0) continue;
        if (alloc.isFilled) break;
        if (alloc.remainingForDay(
              day,
              isCollegeDay,
              ignoreCapOnFreeDays: ignoreDailyCapOnFreeDays,
              isUnderPressure: isUnderPressure,
            ) <=
            0) {
          break;
        }

        // Guard: On college days, allow strictly at most ONE focus activity before college departure
        final isPreCollegeMorningSlot = isCollegeDay && slot.startMinutes < firstFixedStart;
        if (isPreCollegeMorningSlot &&
            floatingBlocks.any(
              (b) => b.dayOfWeek == day && b.startMinutes < firstFixedStart,
            )) {
          continue;
        }

        // Calculate allocation size
        final needed = _calculateAllocation(
          remaining: alloc.remainingMinutes,
          dailyRemaining: alloc.remainingForDay(
            day,
            isCollegeDay,
            ignoreCapOnFreeDays: ignoreDailyCapOnFreeDays,
            isUnderPressure: isUnderPressure,
          ),
          slotDuration: slot.duration,
          maxSessionMinutes: maxSessionMinutes != null
              ? min(maxSessionMinutes, 270)
              : 270,
          allowFinalTail: allowFinalTail,
        );

        final minAllowed = kMinBlockMinutes;
        if (needed < minAllowed) continue;

        // Create the floating block.
        floatingBlocks.add(
          TimeBlock(
            id: '${target.id}_${day}_${slot.startMinutes}',
            label: target.name,
            dayOfWeek: day,
            startMinutes: slot.startMinutes,
            endMinutes: slot.startMinutes + needed,
            type: TimeBlockType.floating,
            parentTargetId: target.id,
          ),
        );

        alloc.allocate(day, needed);
        dailyTargetIds[day]!.add(target.id);
        dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + needed;

        // If this was the pre-college morning session on a college day, remove any remaining morning free slot fragments
        // so the remaining time before college is preserved as a relaxed buffer rather than scheduling a 2nd subject.
        if (isPreCollegeMorningSlot) {
          freeSlotsByDay[day]!.removeWhere((s) => s.startMinutes < firstFixedStart);
        } else {
          // Insert inter-session rest buffer between consecutive focus activities
          final isWeekend = day == kSaturday || day == kSunday;
          final interSessionBreak = isWeekend
              ? (isUnderPressure
                  ? kPressureWeekendBreakMinutes
                  : kWeekendInterSessionBreakMinutes)
              : (isUnderPressure
                  ? kPressureWeekdayBreakMinutes
                  : kWeekdayInterSessionBreakMinutes);
          slot.startMinutes += needed + interSessionBreak;

          if (slot.duration <= 0) {
            freeSlotsByDay[day]!.remove(slot);
          }
        }
        return true;
      }
      return false;
    }

    // ── Phase 1: Unified Weekday & Saturday Supply-Demand Allocation ──
    // Fills natural focus windows (Morning, Afternoon, Late-Night) across Mon-Fri and Saturday
    // using soft affinity (preferred slots first, fallback slots immediately available).

    // Pass 1.1: Weekday structured primary sessions
    for (final target in sortedTargets) {
      final weekdayList = [kMonday, kTuesday, kWednesday, kThursday, kFriday]
        ..sort(
          (a, b) => (dayFixedMinutes[a]! + dailyFloatingMinutes[a]!).compareTo(
            dayFixedMinutes[b]! + dailyFloatingMinutes[b]!,
          ),
        );

      for (final day in weekdayList) {
        if (isWideOpenDay(day)) continue;

        final sessionCap = target.affinity == TimeAffinity.morning
            ? 180
            : (target.affinity == TimeAffinity.lateNight ? 150 : 290);

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: false,
          affinityPreferred: true,
          maxSessionMinutes: sessionCap,
          allowNewTargetOnCollegeDay: true,
        );
      }
    }

    // Pass 1.2: Free-Days & Saturday Deep Focus Spillover
    final spilloverTargets = List<TaskTarget>.from(sortedTargets)
      ..sort((a, b) {
        if (a.priority != b.priority) return a.priority.compareTo(b.priority);
        return _affinityOrder(a.affinity).compareTo(_affinityOrder(b.affinity));
      });

    final freeDayCandidates = [
      kMonday,
      kTuesday,
      kWednesday,
      kThursday,
      kFriday,
      kSaturday,
    ].where((d) => isWideOpenDay(d)).toList();

    for (final target in spilloverTargets) {
      for (final day in freeDayCandidates) {
        final alloc = allocations[target.id]!;
        if (alloc.isFilled) continue;

        final maxCap = target.affinity == TimeAffinity.morning ? 300 : 270;
        final deepBlockMinutes = min(
          alloc.remainingForDay(
            day,
            false,
            ignoreCapOnFreeDays: ignoreDailyCapOnFreeDays,
            isUnderPressure: isUnderPressure,
          ),
          min(alloc.remainingMinutes, maxCap),
        );

        if (deepBlockMinutes < kMinBlockMinutes) continue;

        tryAllocate(
          target: target,
          day: day,
          affinityOnly: false,
          affinityPreferred: true,
          maxSessionMinutes: deepBlockMinutes,
          allowNewTargetOnCollegeDay: true,
          allowMultipleSessionsPerDay: day == kSaturday,
        );
      }
    }

    // Pass 1.3: Iterative unified balancing across Mon-Sat
    bool madeProgress = true;
    while (madeProgress) {
      madeProgress = false;
      final activeDays = [
        kMonday,
        kTuesday,
        kWednesday,
        kThursday,
        kFriday,
        kSaturday,
      ]..sort(
          (a, b) => (dayFixedMinutes[a]! + dailyFloatingMinutes[a]!).compareTo(
            dayFixedMinutes[b]! + dailyFloatingMinutes[b]!,
          ),
        );

      for (final day in activeDays) {
        for (final target in sortedTargets) {
          if (tryAllocate(
            target: target,
            day: day,
            affinityOnly: false,
            affinityPreferred: true,
            allowNewTargetOnCollegeDay: true,
            allowMultipleSessionsPerDay: true,
            allowFinalTail: false,
          )) {
            madeProgress = true;
          }
        }
      }
    }

    // Pass 1.4: Saturday Saturation — exhaust Saturday before touching Sunday
    // Retry all unfilled targets on Saturday with expanded caps and multiple sessions.
    for (final target in sortedTargets) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) continue;

      // Keep trying Saturday until no more progress
      bool satProgress = true;
      while (satProgress && !alloc.isFilled) {
        satProgress = tryAllocate(
          target: target,
          day: kSaturday,
          affinityOnly: false,
          affinityPreferred: false,
          allowNewTargetOnCollegeDay: true,
          allowMultipleSessionsPerDay: true,
          allowFinalTail: true,
        );
      }
    }

    // ── Phase 2: Sunday Fallback (Only if Mon-Sat Capacity Genuinely Saturated) ──
    // Check if Saturday has meaningful free capacity remaining
    final satFreeRemaining = freeSlotsByDay[kSaturday]!
        .fold(0, (sum, s) => sum + s.duration);
    final anyUnfilled = sortedTargets.any((t) => !allocations[t.id]!.isFilled);

    if (anyUnfilled && satFreeRemaining < kMinBlockMinutes) {
      for (final target in sortedTargets) {
        final alloc = allocations[target.id]!;
        if (alloc.isFilled) continue;

        bool sunProgress = true;
        while (sunProgress && !alloc.isFilled) {
          sunProgress = tryAllocate(
            target: target,
            day: kSunday,
            affinityOnly: false,
            affinityPreferred: true,
            allowNewTargetOnCollegeDay: true,
            enforceDailyExertionCap: true,
            allowMultipleSessionsPerDay: true,
            allowFinalTail: true,
          );
        }
      }
    }

    // ── Phase 3: Unified Crumb & Remainder Top-Up ──
    // Step 3a: Extend existing blocks into adjacent free slots
    for (final target in sortedTargets) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) continue;

      var remaining = alloc.remainingMinutes;
      if (remaining <= 0) continue;

      for (int i = 0; i < floatingBlocks.length; i++) {
        final block = floatingBlocks[i];
        if (block.parentTargetId != target.id) continue;

        final day = block.dayOfWeek;
        final slots = freeSlotsByDay[day]!;
        for (final slot in List<FreeSlot>.from(slots)) {
          final gapAfter = slot.startMinutes - block.endMinutes;
          if (gapAfter >= 0 && gapAfter <= 45 && slot.duration > 0) {
            final toAdd = min(remaining, slot.duration);
            if (toAdd > 0) {
              floatingBlocks[i] = block.copyWith(
                endMinutes: block.endMinutes + toAdd,
              );
              alloc.allocate(day, toAdd);
              dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + toAdd;
              slot.startMinutes += toAdd;
              remaining -= toAdd;
              if (slot.duration <= 0) {
                slots.remove(slot);
              }
              break;
            }
          }

          final gapBefore = block.startMinutes - slot.endMinutes;
          if (gapBefore >= 0 && gapBefore <= 45 && slot.duration > 0) {
            final toAdd = min(remaining, slot.duration);
            if (toAdd > 0) {
              floatingBlocks[i] = block.copyWith(
                startMinutes: block.startMinutes - toAdd,
              );
              alloc.allocate(day, toAdd);
              dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + toAdd;
              slot.endMinutes -= toAdd;
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

    // Step 3b: Create new small blocks for remaining shortfall (< 45m)
    // This ensures targets hit 100% quota instead of stalling at 97%.
    for (final target in sortedTargets) {
      final alloc = allocations[target.id]!;
      if (alloc.isFilled) continue;

      final shortfall = alloc.remainingMinutes;
      if (shortfall <= 0 || shortfall > 60) continue;

      // Try Mon-Sat first, then Sunday
      final candidateDays = [kMonday, kTuesday, kWednesday, kThursday, kFriday, kSaturday, kSunday];
      for (final day in candidateDays) {
        final slots = freeSlotsByDay[day]!;
        for (final slot in List<FreeSlot>.from(slots)) {
          if (slot.duration >= shortfall) {
            final blockDuration = max(kMinBlockMinutes, _snapToCleanDuration(shortfall, isFinishing: true));
            if (blockDuration < kMinBlockMinutes) continue;
            final actualDuration = min(blockDuration, slot.duration);

            floatingBlocks.add(
              TimeBlock(
                id: '${target.id}_topup_${day}_${slot.startMinutes}',
                label: target.name,
                dayOfWeek: day,
                startMinutes: slot.startMinutes,
                endMinutes: slot.startMinutes + actualDuration,
                type: TimeBlockType.floating,
                parentTargetId: target.id,
              ),
            );
            alloc.allocate(day, actualDuration);
            dailyFloatingMinutes[day] = dailyFloatingMinutes[day]! + actualDuration;
            slot.startMinutes += actualDuration;
            if (slot.duration <= 0) slots.remove(slot);
            break;
          }
        }
        if (alloc.isFilled) break;
      }
    }

    // ── Step 4: Build result ─────────────────────────────

    // Safety net: filter out any floating crumbs under kMinBlockMinutes
    floatingBlocks.removeWhere(
      (b) => b.type == TimeBlockType.floating && b.durationMinutes < kMinBlockMinutes,
    );

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
        warnings.add(
          AllocationWarning(
            targetId: alloc.target.id,
            targetName: alloc.target.name,
            requestedHours: alloc.target.weeklyHours,
            allocatedHours: allocated,
            shortfallHours: alloc.target.weeklyHours - allocated,
          ),
        );
      }
    }

    return ScheduleResult(
      dailySchedule: dailySchedule,
      warnings: warnings,
      allocatedHours: allocatedHoursMap,
    );
  }

  /// Returns slots that overlap with the given affinity window.
  /// On weekends, tasks are flexible across the entire day to absorb spillover.
  static List<FreeSlot> _getAffinitySlots(
    List<FreeSlot> slots,
    TimeAffinity affinity,
    int day,
  ) {
    if (affinity == TimeAffinity.flexible) return List.from(slots);
    if (day == kSaturday || day == kSunday) {
      return List.from(slots);
    }

    final (windowStart, windowEnd) = _affinityWindow(affinity);

    return slots
        .where(
          (s) => overlaps(s.startMinutes, s.endMinutes, windowStart, windowEnd),
        )
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

  /// Snaps a raw duration to a clean human-friendly grid:
  /// - Blocks ≤ 90m → 15-minute grid (30, 45, 60, 75, 90)
  /// - Blocks 90–180m → 15-minute grid (1h 30m, 1h 45m, 2h, 2h 15m, ...)
  /// - Blocks > 180m → 30-minute grid (3h, 3h 30m, 4h, ...)
  /// When [isFinishing] is true (final quota crumbs), allow 15m minimum.
  static int _snapToCleanDuration(int rawMinutes, {bool isFinishing = false}) {
    if (rawMinutes <= 0) return 0;
    final minBlock = isFinishing ? 15 : kMinBlockMinutes;
    if (rawMinutes < minBlock) return rawMinutes; // Let caller decide if too small

    int grid;
    if (rawMinutes <= 90) {
      grid = 15;
    } else if (rawMinutes <= 180) {
      grid = 15;
    } else {
      grid = 30;
    }

    // Snap down to nearest grid line
    final snapped = (rawMinutes ~/ grid) * grid;
    // If snapping down would leave us below minimum, snap up instead
    if (snapped < minBlock) {
      final snappedUp = ((rawMinutes / grid).ceil()) * grid;
      return snappedUp;
    }
    return snapped;
  }

  /// Calculates the number of minutes to allocate for a session.
  /// Produces clean, human-friendly durations (multiples of 15m or 30m).
  static int _calculateAllocation({
    required int remaining,
    required int dailyRemaining,
    required int slotDuration,
    int? maxSessionMinutes,
    bool allowFinalTail = false,
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
    final leftover = remaining - needed;
    if (leftover > 0 && leftover < kMinBlockMinutes) {
      // If today's slot can absorb the leftover crumb, absorb it today.
      if (remaining <= slotDuration &&
          (maxSessionMinutes == null || remaining <= maxSessionMinutes + 45)) {
        needed = remaining;
      }
    }

    // Enforce minimum block size — all floating blocks must be at least kMinBlockMinutes.
    final effectiveMinBlock = kMinBlockMinutes;
    if (needed < effectiveMinBlock) {
      return 0; // Can't fit a valid block.
    }

    // Snap to clean 15m/30m grid for natural-feeling durations
    final snapped = _snapToCleanDuration(needed, isFinishing: allowFinalTail);
    if (snapped >= effectiveMinBlock &&
        snapped <= remaining &&
        snapped <= dailyRemaining &&
        snapped <= slotDuration) {
      needed = snapped;
    } else if (needed % 5 != 0) {
      // Fallback: at minimum snap to 5-minute grid
      final snap5 = (needed ~/ 5) * 5;
      if (snap5 >= effectiveMinBlock &&
          snap5 <= remaining &&
          snap5 <= dailyRemaining &&
          snap5 <= slotDuration) {
        needed = snap5;
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
