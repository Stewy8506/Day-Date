/// Local data source wrapping Hive CE boxes for schedule persistence.
library;

import 'dart:async';

import 'package:hive_ce/hive.dart';

import 'package:day_date/core/constants/schedule_constants.dart';
import 'package:day_date/features/schedule/data/models/schedule_deviation_model.dart';
import 'package:day_date/features/schedule/data/models/task_completion_model.dart';
import 'package:day_date/features/schedule/data/models/task_target_model.dart';
import 'package:day_date/features/schedule/data/models/time_block_model.dart';

class LocalScheduleDatasource {
  final _changeController = StreamController<void>.broadcast();

  void _notifyChanges() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  Box<TimeBlockModel> get _fixedBlocksBox =>
      Hive.box<TimeBlockModel>(kFixedBlocksBox);

  Box<TaskTargetModel> get _taskTargetsBox =>
      Hive.box<TaskTargetModel>(kTaskTargetsBox);

  Box<ScheduleDeviationModel> get _deviationsBox =>
      Hive.box<ScheduleDeviationModel>(kDeviationsBox);

  Box get _metaBox => Hive.box(kMetaBox);

  Box<TaskCompletionModel>? get _maybeTaskCompletionsBox {
    try {
      if (Hive.isBoxOpen(kTaskCompletionsBox)) {
        return Hive.box<TaskCompletionModel>(kTaskCompletionsBox);
      }
    } catch (_) {}
    return null;
  }

  Future<Box<TaskCompletionModel>> _ensureTaskCompletionsBox() async {
    try {
      if (Hive.isBoxOpen(kTaskCompletionsBox)) {
        return Hive.box<TaskCompletionModel>(kTaskCompletionsBox);
      }
      return await Hive.openBox<TaskCompletionModel>(kTaskCompletionsBox);
    } catch (_) {
      return await Hive.openBox<TaskCompletionModel>(kTaskCompletionsBox);
    }
  }

  // ── Reads ──────────────────────────────────────────────

  List<TimeBlockModel> getFixedBlocks() =>
      _fixedBlocksBox.values.toList();

  List<TaskTargetModel> getTaskTargets() =>
      _taskTargetsBox.values.toList();

  List<ScheduleDeviationModel> getDeviations() =>
      _deviationsBox.values.toList();

  List<TaskCompletionModel> getTaskCompletions() {
    final box = _maybeTaskCompletionsBox;
    if (box == null) return [];
    return box.values.toList();
  }

  // ── Writes ─────────────────────────────────────────────

  Future<void> addDeviation(ScheduleDeviationModel deviation) async {
    await _deviationsBox.put(deviation.id, deviation);
    _notifyChanges();
  }

  Future<void> removeDeviation(String id) async {
    await _deviationsBox.delete(id);
    _notifyChanges();
  }

  Future<void> addFixedBlock(TimeBlockModel block) async {
    await _fixedBlocksBox.put(block.id, block);
    _notifyChanges();
  }

  Future<void> addTaskTarget(TaskTargetModel target) async {
    await _taskTargetsBox.put(target.id, target);
    _notifyChanges();
  }

  Future<void> removeTaskTarget(String id) async {
    await _taskTargetsBox.delete(id);
    _notifyChanges();
  }

  Future<void> saveTaskCompletion(TaskCompletionModel completion) async {
    final box = await _ensureTaskCompletionsBox();
    await box.put(completion.id, completion);
    _notifyChanges();
  }

  Future<void> removeTaskCompletion(String id) async {
    final box = await _ensureTaskCompletionsBox();
    await box.delete(id);
    _notifyChanges();
  }

  // ── Seed ───────────────────────────────────────────────

  Future<bool> isSeeded() async =>
      _metaBox.get('seeded_v3', defaultValue: false) == true;

  Future<void> markSeeded() => _metaBox.put('seeded_v3', true);

  Future<void> seedFixedBlocks(List<TimeBlockModel> blocks) async {
    await _fixedBlocksBox.clear();
    final map = {for (final b in blocks) b.id: b};
    await _fixedBlocksBox.putAll(map);
  }

  Future<void> seedTaskTargets(List<TaskTargetModel> targets) async {
    await _taskTargetsBox.clear();
    final map = {for (final t in targets) t.id: t};
    await _taskTargetsBox.putAll(map);
  }

  // ── Watch ──────────────────────────────────────────────

  /// Emits whenever any of the data boxes changes.
  Stream<void> watchAllChanges() {
    final controller = StreamController<void>.broadcast();

    final sub0 = _changeController.stream.listen((_) => controller.add(null));
    final sub1 = _fixedBlocksBox.watch().listen((_) => controller.add(null));
    final sub2 = _taskTargetsBox.watch().listen((_) => controller.add(null));
    final sub3 = _deviationsBox.watch().listen((_) => controller.add(null));
    StreamSubscription? sub4;
    final compBox = _maybeTaskCompletionsBox;
    if (compBox != null) {
      sub4 = compBox.watch().listen((_) => controller.add(null));
    }

    controller.onCancel = () {
      sub0.cancel();
      sub1.cancel();
      sub2.cancel();
      sub3.cancel();
      sub4?.cancel();
    };

    return controller.stream;
  }
}
