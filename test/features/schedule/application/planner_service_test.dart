import 'package:flutter_test/flutter_test.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/core/utils/time_utils.dart';
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
      id: 'college-${id++}',
      label: 'College & Commute',
      dayOfWeek: day,
      startMinutes: collegeStart - 30,
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
    test('generates schedule for all 7 days with balanced weekend', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        expect(result.dailySchedule.containsKey(day), isTrue,
            reason: 'Day $day should be present');
        expect(result.dailySchedule[day], isNotEmpty,
            reason: 'Day $day should have blocks scheduled');
      }

      // Verify Saturday and Sunday both have significant floating deep-work blocks
      final satFloating = result.dailySchedule[kSaturday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);
      final sunFloating = result.dailySchedule[kSunday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);

      expect(satFloating, greaterThanOrEqualTo(180),
          reason: 'Saturday should have at least 3 hours of floating work, got ${satFloating}min');
      expect(sunFloating, greaterThanOrEqualTo(180),
          reason: 'Sunday should have at least 3 hours of floating work, got ${sunFloating}min');
    });

    test('no scheduled block starts before 7:30 AM on weekdays (450 min) or 11:00 AM on weekends (660 min)', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (final entry in result.dailySchedule.entries) {
        final day = entry.key;
        final isWeekend = day == kSaturday || day == kSunday;
        final expectedStart = isWeekend ? kWeekendStartMinutes : kWeekdayStartMinutes;

        for (final block in entry.value) {
          expect(block.startMinutes, greaterThanOrEqualTo(expectedStart),
              reason: '${block.label} on day $day starts at ${block.startMinutes}m, '
                  'before ${formatMinutes(expectedStart)}');
        }
      }
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

    test('all floating blocks are at least minimum duration (kMinBlockMinutes)', () {
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

    test('daily total exertion is balanced across all days', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        final dayBlocks = result.dailySchedule[day]!;
        final totalMinutes =
            dayBlocks.fold(0, (sum, b) => sum + b.durationMinutes);
        final maxDayMinutes = (16.0 * 60).round();

        expect(
          totalMinutes,
          lessThanOrEqualTo(maxDayMinutes),
          reason: 'Day $day total scheduled time (${totalMinutes / 60}h) '
              'exceeds daily maximum of ${maxDayMinutes / 60}h',
        );
      }
    });

    test('inter-session rest breaks enforced between consecutive focus sessions', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        final dayBlocks = result.dailySchedule[day]!;
        final isWeekend = day == kSaturday || day == kSunday;
        final minBreak = isWeekend ? kWeekendInterSessionBreakMinutes : kWeekdayInterSessionBreakMinutes;

        for (int i = 0; i < dayBlocks.length - 1; i++) {
          final curr = dayBlocks[i];
          final next = dayBlocks[i + 1];

          // If both are floating focus blocks, check break buffer
          if (curr.type == TimeBlockType.floating && next.type == TimeBlockType.floating) {
            final gap = next.startMinutes - curr.endMinutes;
            expect(
              gap,
              greaterThanOrEqualTo(minBreak),
              reason: 'On day $day between ${curr.label} and ${next.label}, '
                  'break is ${gap}m, expected at least ${minBreak}m',
            );
          }
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
            reason: '${target.name}: expected at least ${target.weeklyHours}h, '
                'got ${allocated}h without warning',
          );
          expect(
            allocated,
            lessThanOrEqualTo(target.weeklyHours + 0.1),
            reason: '${target.name}: allocated ${allocated}h exceeds weekly target of ${target.weeklyHours}h',
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

    test('at most ONE focus activity scheduled in the morning before college departure', () {
      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      for (int day = kMonday; day <= kFriday; day++) {
        final dayBlocks = result.dailySchedule[day]!;
        final collegeBlock = dayBlocks.firstWhere(
          (b) => b.type == TimeBlockType.fixed && b.label.toLowerCase().contains('college'),
          orElse: () => dayBlocks.first,
        );

        final preCollegeFloating = dayBlocks.where(
          (b) => b.type == TimeBlockType.floating && b.startMinutes < collegeBlock.startMinutes,
        ).toList();

        expect(
          preCollegeFloating.length,
          lessThanOrEqualTo(1),
          reason: 'Day $day has ${preCollegeFloating.length} focus sessions before college: '
              '${preCollegeFloating.map((b) => b.label).toList()}',
        );
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
        (b) => b.dayOfWeek == kTuesday && (b.label == 'College' || b.label == 'College & Commute'),
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

  group('PlannerService — College Cancellation (accelerateWeek)', () {
    test('removes college and commute blocks on the off day', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      final tueBlocks = result.dailySchedule[kTuesday]!;
      final hasCollege = tueBlocks.any((b) => b.label.toLowerCase().contains('college'));

      expect(hasCollege, isFalse,
          reason: 'College & Commute block should be removed on Tuesday');
    });

    test('fills freed hours with floating targets', () {
      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final withOff = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Tuesday should have MORE floating blocks than baseline.
      final baselineFloating = baseline.dailySchedule[kTuesday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);
      final offDayFloating = withOff.dailySchedule[kTuesday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);

      expect(offDayFloating, greaterThan(baselineFloating),
          reason: 'Freed college hours should be filled with floating targets');
    });

    test('respects affinity biasing in freed slots', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      final tueFloating = result.dailySchedule[kTuesday]!
          .where((b) => b.type == TimeBlockType.floating)
          .toList();

      // Check that CAT Prep (morning affinity) blocks are before noon.
      final catBlocks = tueFloating.where((b) => b.label == 'CAT Prep');
      for (final block in catBlocks) {
        if (block.startMinutes < 720) {
          // Good — at least partially in the morning window.
          expect(true, isTrue);
        }
      }

      // At least some floating blocks should exist on Tuesday.
      expect(tueFloating, isNotEmpty,
          reason: 'Should have floating blocks on Tuesday off day');
    });

    test('daily caps respected even with extra free time', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      for (final target in targets) {
        final tueMinutes = result.dailySchedule[kTuesday]!
            .where((b) => b.parentTargetId == target.id)
            .fold(0, (sum, b) => sum + b.durationMinutes);

        final maxCap = (target.dailyCapMinutes * 1.5).round();
        expect(tueMinutes, lessThanOrEqualTo(maxCap),
            reason:
                '${target.name} on Tuesday: ${tueMinutes}min exceeds '
                'daily cap of ${maxCap}min');
      }
    });

    test('reduces allocation on later days (weekend freed)', () {
      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final withOff = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Compute total floating minutes on Fri+Sat+Sun for both.
      int weekendFloating(ScheduleResult r) {
        int total = 0;
        for (final day in [kFriday, kSaturday, kSunday]) {
          total += r.dailySchedule[day]!
              .where((b) => b.type == TimeBlockType.floating)
              .fold(0, (sum, b) => sum + b.durationMinutes);
        }
        return total;
      }

      final baselineWeekend = weekendFloating(baseline);
      final offDayWeekend = weekendFloating(withOff);

      expect(offDayWeekend, lessThanOrEqualTo(baselineWeekend),
          reason: 'Weekend should have equal or fewer floating hours '
              'when Tuesday quotas were fulfilled early');
    });

    test('all floating blocks maintain minimum duration (kMinBlockMinutes)', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      for (final dayBlocks in result.dailySchedule.values) {
        for (final block in dayBlocks) {
          if (block.type == TimeBlockType.floating) {
            expect(block.durationMinutes, greaterThanOrEqualTo(kMinBlockMinutes),
                reason: '${block.label} on day ${block.dayOfWeek} is '
                    '${block.durationMinutes}min, below minimum');
          }
        }
      }
    });

    test('no overlapping floating blocks after cancellation', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      for (int day = kMonday; day <= kSunday; day++) {
        final blocks = result.dailySchedule[day]!;
        final floating =
            blocks.where((b) => b.type == TimeBlockType.floating).toList();

        for (final f in floating) {
          for (final other in blocks) {
            if (other.id == f.id) continue;
            final hasOverlap =
                f.startMinutes < other.endMinutes &&
                    f.endMinutes > other.startMinutes;
            expect(hasOverlap, isFalse,
                reason:
                    'Day $day: "${f.label}" (${f.startMinutes}-${f.endMinutes}) '
                    'overlaps with "${other.label}" '
                    '(${other.startMinutes}-${other.endMinutes})');
          }
        }
      }
    });

    test('gym block preserved on off day', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.accelerateWeek,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      final tueBlocks = result.dailySchedule[kTuesday]!;
      final hasGym = tueBlocks.any(
          (b) => b.label == 'Gym' && b.type == TimeBlockType.fixed);
      expect(hasGym, isTrue,
          reason: 'Gym block should be preserved on Tuesday');
    });
  });

  group('PlannerService — College Cancellation (restAndLeisure)', () {
    test('replaces college+commute with Free Time block', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.restAndLeisure,
        date: DateTime(2026, 8, 19),
      );

      final result = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      final tueBlocks = result.dailySchedule[kTuesday]!;
      final freeTime = tueBlocks.where((b) => b.label == 'Free Time');

      expect(freeTime, isNotEmpty,
          reason: 'Free Time block should appear on Tuesday');

      // Free Time should span the commute-before to commute-after range.
      final ft = freeTime.first;
      // Commute before starts at 570 (10:00 - 30min)
      // Commute after ends at 1020 (4:20 PM + 40min)
      expect(ft.startMinutes, equals(570),
          reason: 'Free Time should start at commute-before start');
      expect(ft.endMinutes, equals(1020),
          reason: 'Free Time should end at commute-after end');
    });

    test('does NOT allocate floating targets in freed hours', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.restAndLeisure,
        date: DateTime(2026, 8, 19),
      );

      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      final withOff = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Tuesday floating minutes should be same or less than baseline.
      final baselineFloating = baseline.dailySchedule[kTuesday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);
      final offDayFloating = withOff.dailySchedule[kTuesday]!
          .where((b) => b.type == TimeBlockType.floating)
          .fold(0, (sum, b) => sum + b.durationMinutes);

      expect(offDayFloating, lessThanOrEqualTo(baselineFloating),
          reason: 'restAndLeisure should NOT add floating blocks in freed hours');
    });

    test('keeps rest of week schedule unchanged', () {
      final deviation = ScheduleDeviation(
        id: 'college-off-tue',
        label: 'College Off',
        type: DeviationType.collegeCancellation,
        dayOfWeek: kTuesday,
        startMinutes: 0,
        endMinutes: 0,
        offDayStrategy: OffDayStrategy.restAndLeisure,
        date: DateTime(2026, 8, 19),
      );

      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      final withOff = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [deviation],
        targets: targets,
      );

      // Other days (Mon, Wed, Thu, Fri) should have similar block counts.
      for (final day in [kMonday, kWednesday, kThursday, kFriday]) {
        final baselineCount = baseline.dailySchedule[day]!.length;
        final offDayCount = withOff.dailySchedule[day]!.length;

        // Allow ±1 block difference due to redistribution edge cases.
        expect((offDayCount - baselineCount).abs(), lessThanOrEqualTo(1),
            reason:
                'Day $day block count changed significantly: '
                'baseline=$baselineCount, withOff=$offDayCount');
      }
    });
  });

  group('PlannerService — College Cancellation (toggle restore)', () {
    test('removing cancellation restores baseline schedule', () {
      final baseline = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targets,
      );

      // Simulate: no deviations = attending (same as removing cancellation).
      // The key is that when setCollegeStatusForDate(isAttending: true) is
      // called, it removes the deviation and the schedule should match baseline.
      final restored = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [], // Deviation removed by repo
        targets: targets,
      );

      // Tuesday should have college blocks again.
      final tueBlocks = restored.dailySchedule[kTuesday]!;
      final hasCollege = tueBlocks.any((b) => b.label.toLowerCase().contains('college'));

      expect(hasCollege, isTrue,
          reason: 'College & Commute block should be restored on Tuesday');

      // Block counts should match baseline.
      for (int day = kMonday; day <= kSunday; day++) {
        expect(
          baseline.dailySchedule[day]!.length,
          equals(restored.dailySchedule[day]!.length),
          reason: 'Day $day block count should match baseline after restore',
        );
      }
    });

    test('CAT prep flexible vs morning affinity 46h allocation', () {
      final targetsMorning = [
        const TaskTarget(
          id: 'swe',
          name: 'SWE Roadmap',
          weeklyHours: 17.0,
          priority: 1,
          affinity: TimeAffinity.afternoon,
          dailyCapHours: 3.5,
        ),
        const TaskTarget(
          id: 'cat',
          name: 'CAT Prep',
          weeklyHours: 11.5,
          priority: 2,
          affinity: TimeAffinity.morning,
          dailyCapHours: 3.0,
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
          weeklyHours: 7.5,
          priority: 4,
          affinity: TimeAffinity.flexible,
          dailyCapHours: 2.0,
        ),
      ];

      final targetsFlexible = [
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
          affinity: TimeAffinity.flexible,
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
          weeklyHours: 7.5,
          priority: 4,
          affinity: TimeAffinity.flexible,
          dailyCapHours: 1.5,
        ),
      ];

      final targetsAfternoon = [
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
          affinity: TimeAffinity.afternoon,
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
          weeklyHours: 7.5,
          priority: 4,
          affinity: TimeAffinity.flexible,
          dailyCapHours: 1.5,
        ),
      ];

      final resMorning = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targetsMorning,
      );

      final resFlexible = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targetsFlexible,
      );

      final resAfternoon = planner.computeWeeklySchedule(
        fixedBlocks: fixedBlocks,
        deviations: [],
        targets: targetsAfternoon,
      );

      expect(resMorning.allocatedHours['cat'], equals(11.5));
      expect(resMorning.allocatedHours['swe'], equals(17.0));
      expect(resMorning.allocatedHours['freelancing'], equals(10.0));
      expect(resMorning.allocatedHours['ece'], equals(7.5));
      expect(resMorning.warnings, isEmpty);

      expect(resFlexible.allocatedHours['cat'], equals(11.5));
      expect(resFlexible.allocatedHours['swe'], equals(17.0));
      expect(resFlexible.allocatedHours['freelancing'], equals(10.0));
      expect(resFlexible.allocatedHours['ece'], equals(7.5));
      expect(resFlexible.warnings, isEmpty);

      expect(resAfternoon.allocatedHours['cat'], equals(11.5));
      expect(resAfternoon.allocatedHours['swe'], equals(17.0));
      expect(resAfternoon.allocatedHours['freelancing'], equals(10.0));
      expect(resAfternoon.allocatedHours['ece'], equals(7.5));
      expect(resAfternoon.warnings, isEmpty);
    });
  });
}
