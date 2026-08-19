/// Mapper extensions to convert between Hive models and domain entities.
library;

import 'package:day_date/features/schedule/data/models/schedule_deviation_model.dart';
import 'package:day_date/features/schedule/data/models/task_target_model.dart';
import 'package:day_date/features/schedule/data/models/time_block_model.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';

// ──────────────────────────────────────────────────────────
// TimeBlock mappings
// ──────────────────────────────────────────────────────────

extension TimeBlockModelMapper on TimeBlockModel {
  TimeBlock toEntity() => TimeBlock(
        id: id,
        label: label,
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        type: _toEntityType(typeModel),
        parentTargetId: parentTargetId,
      );

  static TimeBlockType _toEntityType(TimeBlockTypeModel model) {
    switch (model) {
      case TimeBlockTypeModel.fixed:
        return TimeBlockType.fixed;
      case TimeBlockTypeModel.floating:
        return TimeBlockType.floating;
      case TimeBlockTypeModel.deviation:
        return TimeBlockType.deviation;
    }
  }
}

extension TimeBlockEntityMapper on TimeBlock {
  TimeBlockModel toModel() => TimeBlockModel.create(
        id: id,
        label: label,
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        typeModel: _toModelType(type),
        parentTargetId: parentTargetId,
      );

  static TimeBlockTypeModel _toModelType(TimeBlockType type) {
    switch (type) {
      case TimeBlockType.fixed:
        return TimeBlockTypeModel.fixed;
      case TimeBlockType.floating:
        return TimeBlockTypeModel.floating;
      case TimeBlockType.deviation:
        return TimeBlockTypeModel.deviation;
    }
  }
}

// ──────────────────────────────────────────────────────────
// TaskTarget mappings
// ──────────────────────────────────────────────────────────

extension TaskTargetModelMapper on TaskTargetModel {
  TaskTarget toEntity() => TaskTarget(
        id: id,
        name: name,
        weeklyHours: weeklyHours,
        priority: priority,
        affinity: _toEntityAffinity(affinityModel),
        dailyCapHours: dailyCapHours,
      );

  static TimeAffinity _toEntityAffinity(TimeAffinityModel model) {
    switch (model) {
      case TimeAffinityModel.morning:
        return TimeAffinity.morning;
      case TimeAffinityModel.afternoon:
        return TimeAffinity.afternoon;
      case TimeAffinityModel.lateNight:
        return TimeAffinity.lateNight;
      case TimeAffinityModel.flexible:
        return TimeAffinity.flexible;
    }
  }
}

extension TaskTargetEntityMapper on TaskTarget {
  TaskTargetModel toModel() => TaskTargetModel.create(
        id: id,
        name: name,
        weeklyHours: weeklyHours,
        priority: priority,
        affinityModel: _toModelAffinity(affinity),
        dailyCapHours: dailyCapHours,
      );

  static TimeAffinityModel _toModelAffinity(TimeAffinity affinity) {
    switch (affinity) {
      case TimeAffinity.morning:
        return TimeAffinityModel.morning;
      case TimeAffinity.afternoon:
        return TimeAffinityModel.afternoon;
      case TimeAffinity.lateNight:
        return TimeAffinityModel.lateNight;
      case TimeAffinity.flexible:
        return TimeAffinityModel.flexible;
    }
  }
}

// ──────────────────────────────────────────────────────────
// ScheduleDeviation mappings
// ──────────────────────────────────────────────────────────

extension ScheduleDeviationModelMapper on ScheduleDeviationModel {
  ScheduleDeviation toEntity() => ScheduleDeviation(
        id: id,
        label: label,
        type: _toEntityType(typeModel),
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        extendsBlockId: extendsBlockId,
        extensionMinutes: extensionMinutes,
        offDayStrategy: _toEntityStrategy(offDayStrategyModel),
        date: date,
      );

  static DeviationType _toEntityType(DeviationTypeModel model) {
    switch (model) {
      case DeviationTypeModel.blockout:
        return DeviationType.blockout;
      case DeviationTypeModel.extension:
        return DeviationType.extension;
      case DeviationTypeModel.collegeCancellation:
        return DeviationType.collegeCancellation;
    }
  }

  static OffDayStrategy? _toEntityStrategy(OffDayStrategyModel? model) {
    if (model == null) return null;
    switch (model) {
      case OffDayStrategyModel.accelerateWeek:
        return OffDayStrategy.accelerateWeek;
      case OffDayStrategyModel.restAndLeisure:
        return OffDayStrategy.restAndLeisure;
    }
  }
}

extension ScheduleDeviationEntityMapper on ScheduleDeviation {
  ScheduleDeviationModel toModel() => ScheduleDeviationModel.create(
        id: id,
        label: label,
        typeModel: _toModelType(type),
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        extendsBlockId: extendsBlockId,
        extensionMinutes: extensionMinutes,
        offDayStrategyModel: _toModelStrategy(offDayStrategy),
        date: date,
      );

  static DeviationTypeModel _toModelType(DeviationType type) {
    switch (type) {
      case DeviationType.blockout:
        return DeviationTypeModel.blockout;
      case DeviationType.extension:
        return DeviationTypeModel.extension;
      case DeviationType.collegeCancellation:
        return DeviationTypeModel.collegeCancellation;
    }
  }

  static OffDayStrategyModel? _toModelStrategy(OffDayStrategy? strategy) {
    if (strategy == null) return null;
    switch (strategy) {
      case OffDayStrategy.accelerateWeek:
        return OffDayStrategyModel.accelerateWeek;
      case OffDayStrategy.restAndLeisure:
        return OffDayStrategyModel.restAndLeisure;
    }
  }
}

