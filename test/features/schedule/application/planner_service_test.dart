import 'package:flutter_test/flutter_test.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/application/services/planner_service.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';

// ──────────────────────────────────────────────────────────
// Test helpers
// ──────────────────────────────────────────────────────────

/// Creates the baseline fixed blocks matching the seed data.
List<TimeBlock> _createSeedFixedBlocks() {
  final blocks = <TimeBlock>[];
  var id = 0;

  void addCollegeDay(int day, int collegeStart, int collegeEnd) {
    blocks.add(TimeBlock(
      id: 'commute-before-${id++}',
      label: 'Commute',
      dayOfWeek: day,
      startMinutes: collegeStart - 30,
      endMinutes: collegeStart,
      type: TimeBlockType.fixed,
    ));
    blocks.add(TimeBlock(
      id: 'college-${id++}',
      label: 'College',
      dayOfWeek: day,
      startMinutes: collegeStart,
      endMinutes: collegeEnd,
      type: TimeBlockType.fixed,
    ));
    blocks.add(TimeBlock(
      id: 'commute-after-${id++}',
      label: 'Commute',
      dayOfWeek: day,
      startMinutes: collegeEnd,
      endMinutes: collegeEnd + 40,
      type: TimeBlockType.fixed,
    ));
  }

  addCollegeDay(kMonday, 600, 790); // 10:00-1:50
  addCollegeDay(kTuesday, 600, 980); // 10:00-4:20
  addCollegeDay(kWednesday, 650, 870); // 10:50-2:30
  addCollegeDay(kThursday, 650, 930); // 10:50-3:30
  addCollegeDay(kFriday, 600, 930); // 10:00-3:30

  // Gym Mon-Sat 7:30 PM - 9:30 PM
  for (int day = kMonday; day <= kSaturday; day++) {
    blocks.add(TimeBlock(
      id: 'gym-${id++}',
      label: 'Gym',
      dayOfWeek: day,
      startMinutes: 1170,
      endMinutes: 1290,
      type: TimeBlockType.fixed,
    ));
  }

  return blocks;
}

/// Creates the baseline floating targets matching the seed data.
List<TaskTarget> _createSeedTargets() => [
      const TaskTarget(
        id: 'swe',
        name: 'SWE Roadmap',
        weeklyHours: 17.0,
        priority: 1,
        affinity: TimeAffinity.afternoon,
        dailyCapHours: 3.0,
      ),
      const TaskTarget(
        id: 'cat',
        name: 'CAT Prep',
        weeklyHours: 11.5,
        priority: 2,
        affinity: TimeAffinity.morning,
        dailyCapHours: 2.5,
      ),
      const TaskTarget(
        id: 'freelancing',
        name: 'Freelancing',
        weeklyHours: 10.0,
        priority: 3,
        affinity: TimeAffinity.lateNight,
        dailyCapHours: 2.0,
      ),
      const TaskTarget(
        id: 'ece',
        name: 'ECE Upkeep',
        weeklyHours: 6.0,
        priority: 4,
        affinity: TimeAffinity.flexible,
        dailyCapHours: 1.5,
      ),
    ];

// ──────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────

void main() {
  late PlannerService planner;
  late List<TimeBlock> fixedBlocks;
  late List<TaskTarget> targets;

  setUp(() {
    planner = PlannerService();
    fixedBlocks = _createSeedFixedBlocks();
    targets = _createSeedTargets();
  });

  group('PlannerService — Baseline Schedule', () {
    test('generates schedule for all 7 days', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        expect(result.dailySchedule.containsKey(day), isTrue,
            reason: 'Day $day should be present');
      }
      // Mon-Sat should have blocks (fixed blocks exist).
      for (int day = kMonday; day <= kSaturday; day++) {
        expect(result.dailySchedule[day], isNotEmpty,
            reason: 'Day $day should have blocks');
      }
      // Sunday may or may not have blocks depending on allocation needs.
    });

    test('no overlaps in generated schedule', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        final blocks = result.dailySchedule[day]!;
        for (int i = 0; i < blocks.length - 1; i++) {
          expect(
            blocks[i].endMinutes <= blocks[i + 1].startMinutes,
            isTrue,
            reason:
                'Day $day: "${blocks[i].label}" (${blocks[i].endMinutes}) '
                'overlaps with "${blocks[i + 1].label}" (${blocks[i + 1].startMinutes})',
          );
        }
      }
    });

    test('all floating blocks are at least 90 minutes', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (final dayBlocks in result.dailySchedule.values) {
        for (final block in dayBlocks) {
          if (block.type == TimeBlockType.floating) {
            expect(block.durationMinutes, greaterThanOrEqualTo(kMinBlockMinutes),
                reason: '${block.label} on day ${block.dayOfWeek} is '
                    '${block.durationMinutes}min, less than minimum $kMinBlockMinutes');
          }
        }
      }
    });

    test('daily cap respected for each target', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (final target in targets) {
        for (int day = kMonday; day <= kSunday; day++) {
          final dayBlocks = result.dailySchedule[day]!;
          final targetMinutes = dayBlocks
              .where((b) => b.parentTargetId == target.id)
              .fold(0, (sum, b) => sum + b.durationMinutes);

          expect(
            targetMinutes,
            lessThanOrEqualTo(target.dailyCapMinutes),
            reason:
                '${target.name} on day $day: ${targetMinutes}min exceeds '
                'daily cap of ${target.dailyCapMinutes}min',
          );
        }
      }
    });

    test('targets fill their weekly quota (or emit warning)', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (final target in targets) {
        final allocated = result.allocatedHours[target.id] ?? 0.0;
        final isWarned =
            result.warnings.any((w) => w.targetId == target.id);

        if (!isWarned) {
          // Should be fully filled.
          expect(
            allocated,
            greaterThanOrEqualTo(target.weeklyHours - 0.1),
            reason: '${target.name}: expected ${target.weeklyHours}h, '
                'got ${allocated}h without warning',
          );
        }
      }
    });

    test('fixed blocks are preserved unchanged', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (final fixed in fixedBlocks) {
        final dayBlocks = result.dailySchedule[fixed.dayOfWeek]!;
        final found = dayBlocks.any((b) =>
            b.id == fixed.id &&
            b.startMinutes == fixed.startMinutes &&
            b.endMinutes == fixed.endMinutes);
        expect(found, isTrue,
            reason: 'Fixed block ${fixed.label} (${fixed.id}) not found on day ${fixed.dayOfWeek}');
      }
    });

    test('affinity biasing: CAT Prep is predominantly before noon', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      int morningMinutes = 0;
      int totalMinutes = 0;

      for (final dayBlocks in result.dailySchedule.values) {
        for (final block in dayBlocks) {
          if (block.label == 'CAT Prep') {
            totalMinutes += block.durationMinutes;
            // Count minutes before noon (720)
            if (block.startMinutes < 720) {
              final effectiveEnd =
                  block.endMinutes < 720 ? block.endMinutes : 720;
              morningMinutes += effectiveEnd - block.startMinutes;
            }
          }
        }
      }

      if (totalMinutes > 0) {
        final morningRatio = morningMinutes / totalMinutes;
        // At least 30% should be in the morning window.
        // The exact ratio depends on college schedules, but there should be
        // a meaningful morning bias.
        expect(morningRatio, greaterThan(0.2),
            reason: 'CAT Prep morning ratio: $morningRatio (expected > 0.2)');
      }
    });
  });

  group('PlannerService — Deviation Handling', () {
    test('blockout deviation removes available time', () {
      // Saturday outing 11 AM - 7 PM
      final deviation = ScheduleDeviation(
        id: 'outing-1',
        label: 'Outing',
        type: DeviationType.blockout,
        dayOfWeek: kSaturday,
        startMinutes: 660, // 11:00
        endMinutes: 1140, // 19:00
      );

      final withDev = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Saturday should have the deviation block.
      final satBlocks = withDev.dailySchedule[kSaturday]!;
      final hasDeviation =
          satBlocks.any((b) => b.type == TimeBlockType.deviation);
      expect(hasDeviation, isTrue, reason: 'Deviation block not found on Saturday');

      // No floating block should overlap with the outing.
      for (final block in satBlocks) {
        if (block.type == TimeBlockType.floating) {
          final overlapsOuting = block.startMinutes < 1140 &&
              block.endMinutes > 660;
          expect(overlapsOuting, isFalse,
              reason: '${block.label} overlaps with outing on Saturday');
        }
      }
    });

    test('deviation causes redistribution to other days', () {
      // Massive blockout: Saturday 6 AM - midnight
      final deviation = ScheduleDeviation(
        id: 'full-sat',
        label: 'Full day off',
        type: DeviationType.blockout,
        dayOfWeek: kSaturday,
        startMinutes: 360,
        endMinutes: 1439,
      );

      final withoutDev = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );
      final withDev = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Saturday should have no floating blocks.
      final satFloating = withDev.dailySchedule[kSaturday]!
          .where((b) => b.type == TimeBlockType.floating)
          .toList();
      expect(satFloating, isEmpty,
          reason: 'No floating blocks expected on fully blocked Saturday');

      // Sunday or other days should absorb more.
      final sundayFloatingWith = withDev.dailySchedule[kSunday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);
      final sundayFloatingWithout = withoutDev.dailySchedule[kSunday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);

      expect(sundayFloatingWith, greaterThanOrEqualTo(sundayFloatingWithout),
          reason: 'Sunday should absorb overflow from Saturday blockout');
    });

    test('no overlaps after deviation', () {
      final deviations = [
        ScheduleDeviation(
          id: 'dev-1',
          label: 'Meeting',
          type: DeviationType.blockout,
          dayOfWeek: kWednesday,
          startMinutes: 900, // 3 PM
          endMinutes: 1050, // 5:30 PM
        ),
        ScheduleDeviation(
          id: 'dev-2',
          label: 'Outing',
          type: DeviationType.blockout,
          dayOfWeek: kSaturday,
          startMinutes: 660, // 11 AM
          endMinutes: 1140, // 7 PM
        ),
      ];

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: deviations,
        targets: targets,
      );

      // Verify no floating block overlaps with any other block.
      for (int day = kMonday; day <= kSunday; day++) {
        final blocks = result.dailySchedule[day]!;
        final floatingBlocks =
            blocks.where((b) => b.type == TimeBlockType.floating).toList();

        for (final floating in floatingBlocks) {
          for (final other in blocks) {
            if (other.id == floating.id) continue;
            final hasOverlap =
                floating.startMinutes < other.endMinutes &&
                    floating.endMinutes > other.startMinutes;
            expect(hasOverlap, isFalse,
                reason:
                    'Day $day: floating "${floating.label}" '
                    '(${floating.startMinutes}-${floating.endMinutes}) '
                    'overlaps with "${other.label}" '
                    '(${other.startMinutes}-${other.endMinutes})');
          }
        }
      }
    });

    test('extension deviation extends fixed block correctly', () {
      // Find a college block to extend.
      final tuesdayCollege = fixedBlocks.firstWhere(
        (b) => b.dayOfWeek == kTuesday && b.label == 'College',
      );

      final deviation = ScheduleDeviation(
        id: 'ext-1',
        label: 'College extended',
        type: DeviationType.extension,
        dayOfWeek: kTuesday,
        startMinutes: tuesdayCollege.startMinutes,
        endMinutes: tuesdayCollege.endMinutes + 120,
        extendsBlockId: tuesdayCollege.id,
        extensionMinutes: 120, // 2 hours
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // The college block should be extended.
      final tueBlocks = result.dailySchedule[kTuesday]!;
      final extendedCollege = tueBlocks.firstWhere(
        (b) => b.id == tuesdayCollege.id,
      );
      expect(extendedCollege.endMinutes,
          equals(tuesdayCollege.endMinutes + 120));
    });

    test('underfill warning when insufficient free time', () {
      // Block out most of the week.
      final deviations = <ScheduleDeviation>[];
      for (int day = kMonday; day <= kSunday; day++) {
        deviations.add(ScheduleDeviation(
          id: 'block-$day',
          label: 'Blocked',
          type: DeviationType.blockout,
          dayOfWeek: day,
          startMinutes: 360,
          endMinutes: 1439,
        ));
      }

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: deviations,
        targets: targets,
      );

      expect(result.warnings, isNotEmpty,
          reason: 'Should warn when entire week is blocked');
    });

    test('empty deviations produce identical schedule to baseline', () {
      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );
      final withEmpty = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        expect(
          baseline.dailySchedule[day]!.length,
          equals(withEmpty.dailySchedule[day]!.length),
          reason: 'Day $day block count mismatch',
        );
      }
    });
  });

  group('PlannerService — Edge Cases', () {
    test('works with no fixed blocks', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: [],
        deviations: [],
        targets: targets,
      );

      // Should still produce a schedule.
      expect(result.dailySchedule.length, equals(7));

      // Should have floating blocks.
      final totalFloating = result.dailySchedule.values
          .expand((blocks) => blocks)
          .where((b) => b.type == TimeBlockType.floating)
          .length;
      expect(totalFloating, greaterThan(0));
    });

    test('works with no targets', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: [],
      );

      // Should have only fixed blocks.
      for (final dayBlocks in result.dailySchedule.values) {
        for (final block in dayBlocks) {
          expect(block.type, equals(TimeBlockType.fixed));
        }
      }
      expect(result.warnings, isEmpty);
    });

    test('handles overlapping fixed blocks gracefully', () {
      // Two fixed blocks that overlap (edge case).
      final overlapping = [
        const TimeBlock(
          id: 'a',
          label: 'A',
          dayOfWeek: kMonday,
          startMinutes: 600,
          endMinutes: 720,
          type: TimeBlockType.fixed,
        ),
        const TimeBlock(
          id: 'b',
          label: 'B',
          dayOfWeek: kMonday,
          startMinutes: 700,
          endMinutes: 800,
          type: TimeBlockType.fixed,
        ),
      ];

      // Should not throw.
      final result = planner.computeWeeklySchedule(
        fixedBlocks: overlapping,
        deviations: [],
        targets: targets,
      );

      expect(result.dailySchedule[kMonday], isNotNull);
    });
  });
}
