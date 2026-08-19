/// Concrete implementation of [ScheduleRepository] backed by Hive CE.
library;

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/data/datasources/local_schedule_datasource.dart';
import 'package:day_date/features/schedule/data/models/model_mappers.dart';
import 'package:day_date/features/schedule/data/models/schedule_deviation_model.dart';
import 'package:day_date/features/schedule/data/models/task_target_model.dart';
import 'package:day_date/features/schedule/data/models/time_block_model.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';
import 'package:day_date/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:uuid/uuid.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final LocalScheduleDatasource _datasource;

  ScheduleRepositoryImpl(this._datasource);

  @override
  Future<List<TimeBlock>> getFixedBlocks() async =>
      _datasource.getFixedBlocks().map((m) => m.toEntity()).toList();

  @override
  Future<List<TaskTarget>> getTaskTargets() async =>
      _datasource.getTaskTargets().map((m) => m.toEntity()).toList();

  @override
  Future<List<ScheduleDeviation>> getDeviations() async =>
      _datasource.getDeviations().map((m) => m.toEntity()).toList();

  @override
  Future<void> addDeviation(ScheduleDeviation deviation) async =>
      _datasource.addDeviation(deviation.toModel());

  @override
  Future<void> removeDeviation(String id) async =>
      _datasource.removeDeviation(id);

  @override
  Future<bool> isFirstLaunch() async => !(await _datasource.isSeeded());

  @override
  Future<void> seedIfEmpty() async {
    if (await _datasource.isSeeded()) return;

    const uuid = Uuid();

    // ── Fixed Blocks: College + Commute ──────────────────

    final fixedBlocks = <TimeBlockModel>[];

    void addCollegeDay({
      required int day,
      required int collegeStart, // minutes since midnight
      required int collegeEnd,
    }) {
      final collegeId = uuid.v4();
      final commuteBeforeId = uuid.v4();
      final commuteAfterId = uuid.v4();

      // Commute before college (30 min)
      fixedBlocks.add(TimeBlockModel.create(
        id: commuteBeforeId,
        label: 'Commute',
        dayOfWeek: day,
        startMinutes: collegeStart - 30,
        endMinutes: collegeStart,
        typeModel: TimeBlockTypeModel.fixed,
      ));

      // College block
      fixedBlocks.add(TimeBlockModel.create(
        id: collegeId,
        label: 'College',
        dayOfWeek: day,
        startMinutes: collegeStart,
        endMinutes: collegeEnd,
        typeModel: TimeBlockTypeModel.fixed,
      ));

      // Commute after college (40 min)
      fixedBlocks.add(TimeBlockModel.create(
        id: commuteAfterId,
        label: 'Commute',
        dayOfWeek: day,
        startMinutes: collegeEnd,
        endMinutes: collegeEnd + 40,
        typeModel: TimeBlockTypeModel.fixed,
      ));
    }

    // Monday: 10:00 AM - 1:50 PM
    addCollegeDay(day: kMonday, collegeStart: 600, collegeEnd: 790);
    // Tuesday: 10:00 AM - 4:20 PM
    addCollegeDay(day: kTuesday, collegeStart: 600, collegeEnd: 980);
    // Wednesday: 10:50 AM - 2:30 PM
    addCollegeDay(day: kWednesday, collegeStart: 650, collegeEnd: 870);
    // Thursday: 10:50 AM - 3:30 PM
    addCollegeDay(day: kThursday, collegeStart: 650, collegeEnd: 930);
    // Friday: 10:00 AM - 3:30 PM
    addCollegeDay(day: kFriday, collegeStart: 600, collegeEnd: 930);

    // ── Fixed Blocks: Gym (Mon-Sat, 7:30 PM - 9:30 PM) ──
    for (int day = kMonday; day <= kSaturday; day++) {
      fixedBlocks.add(TimeBlockModel.create(
        id: uuid.v4(),
        label: 'Gym',
        dayOfWeek: day,
        startMinutes: 1170, // 19:30
        endMinutes: 1290, // 21:30
        typeModel: TimeBlockTypeModel.fixed,
      ));
    }

    await _datasource.seedFixedBlocks(fixedBlocks);

    // ── Floating Targets ─────────────────────────────────

    final targets = <TaskTargetModel>[
      TaskTargetModel.create(
        id: uuid.v4(),
        name: 'SWE Roadmap',
        weeklyHours: 17.0,
        priority: 1,
        affinityModel: TimeAffinityModel.afternoon,
        dailyCapHours: 3.0,
      ),
      TaskTargetModel.create(
        id: uuid.v4(),
        name: 'CAT Prep',
        weeklyHours: 11.5,
        priority: 2,
        affinityModel: TimeAffinityModel.morning,
        dailyCapHours: 2.5,
      ),
      TaskTargetModel.create(
        id: uuid.v4(),
        name: 'Freelancing',
        weeklyHours: 10.0,
        priority: 3,
        affinityModel: TimeAffinityModel.lateNight,
        dailyCapHours: 2.0,
      ),
      TaskTargetModel.create(
        id: uuid.v4(),
        name: 'ECE Upkeep',
        weeklyHours: 6.0,
        priority: 4,
        affinityModel: TimeAffinityModel.flexible,
        dailyCapHours: 1.5,
      ),
    ];

    await _datasource.seedTaskTargets(targets);
    await _datasource.markSeeded();
  }

  @override
  Future<void> setCollegeStatusForDate(
    DateTime date, {
    required bool isAttending,
    OffDayStrategy strategy = OffDayStrategy.accelerateWeek,
  }) async {
    final dayOfWeek = date.weekday;

    // Find existing collegeCancellation deviations for this day.
    final existing = _datasource.getDeviations().where((d) =>
        d.typeModel == DeviationTypeModel.collegeCancellation &&
        d.dayOfWeek == dayOfWeek &&
        _isSameDate(d.date, date));

    if (!isAttending) {
      // Mark as off — create deviation if not already present.
      if (existing.isEmpty) {
        final deviation = ScheduleDeviationModel.create(
          id: const Uuid().v4(),
          label: 'College Off',
          typeModel: DeviationTypeModel.collegeCancellation,
          dayOfWeek: dayOfWeek,
          startMinutes: 0,
          endMinutes: 0,
          offDayStrategyModel: strategy == OffDayStrategy.restAndLeisure
              ? OffDayStrategyModel.restAndLeisure
              : OffDayStrategyModel.accelerateWeek,
          date: date,
        );
        await _datasource.addDeviation(deviation);
      }
    } else {
      // Restore attending — remove the college cancellation deviations.
      for (final dev in existing.toList()) {
        await _datasource.removeDeviation(dev.id);
      }
    }
  }

  /// Checks if two nullable DateTimes represent the same calendar date.
  static bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      // If stored deviation has no date, match by dayOfWeek only.
      return a == null && b == null;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Stream<void> watchAllChanges() => _datasource.watchAllChanges();
}
