/// Local data source wrapping Hive CE boxes for schedule persistence.
library;

import 'dart:async';

import 'package:hive_ce/hive.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/data/models/schedule_deviation_model.dart';
import 'package:day_date/features/schedule/data/models/task_target_model.dart';
import 'package:day_date/features/schedule/data/models/time_block_model.dart';

class LocalScheduleDatasource {
  Box<TimeBlockModel> get _fixedBlocksBox =>
      Hive.box<TimeBlockModel>(kFixedBlocksBox);

  Box<TaskTargetModel> get _taskTargetsBox =>
      Hive.box<TaskTargetModel>(kTaskTargetsBox);

  Box<ScheduleDeviationModel> get _deviationsBox =>
      Hive.box<ScheduleDeviationModel>(kDeviationsBox);

  Box get _metaBox => Hive.box(kMetaBox);

  // ── Reads ──────────────────────────────────────────────

  List<TimeBlockModel> getFixedBlocks() =>
      _fixedBlocksBox.values.toList();

  List<TaskTargetModel> getTaskTargets() =>
      _taskTargetsBox.values.toList();

  List<ScheduleDeviationModel> getDeviations() =>
      _deviationsBox.values.toList();

  // ── Writes ─────────────────────────────────────────────

  Future<void> addDeviation(ScheduleDeviationModel deviation) =>
      _deviationsBox.put(deviation.id, deviation);

  Future<void> removeDeviation(String id) =>
      _deviationsBox.delete(id);

  Future<void> addFixedBlock(TimeBlockModel block) =>
      _fixedBlocksBox.put(block.id, block);

  Future<void> addTaskTarget(TaskTargetModel target) =>
      _taskTargetsBox.put(target.id, target);

  // ── Seed ───────────────────────────────────────────────

  Future<bool> isSeeded() async =>
      _metaBox.get('seeded', defaultValue: false) == true;

  Future<void> markSeeded() => _metaBox.put('seeded', true);

  Future<void> seedFixedBlocks(List<TimeBlockModel> blocks) async {
    final map = {for (final b in blocks) b.id: b};
    await _fixedBlocksBox.putAll(map);
  }

  Future<void> seedTaskTargets(List<TaskTargetModel> targets) async {
    final map = {for (final t in targets) t.id: t};
    await _taskTargetsBox.putAll(map);
  }

  // ── Watch ──────────────────────────────────────────────

  /// Emits whenever any of the three data boxes changes.
  Stream<void> watchAllChanges() {
    final controller = StreamController<void>.broadcast();

    final sub1 = _fixedBlocksBox.watch().listen((_) => controller.add(null));
    final sub2 = _taskTargetsBox.watch().listen((_) => controller.add(null));
    final sub3 = _deviationsBox.watch().listen((_) => controller.add(null));

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
    };

    return controller.stream;
  }
}
