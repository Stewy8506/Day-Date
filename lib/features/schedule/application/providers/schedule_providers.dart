/// Riverpod providers for the schedule feature.
///
/// Exposes the computed daily schedule as a reactive stream that
/// automatically rebuilds when the underlying Hive data changes.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:day_date/features/schedule/application/services/planner_service.dart';
import 'package:day_date/features/schedule/data/datasources/local_schedule_datasource.dart';
import 'package:day_date/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/repositories/schedule_repository.dart';

// ── Infrastructure providers ────────────────────────────

final localScheduleDatasourceProvider = Provider<LocalScheduleDatasource>(
  (ref) => LocalScheduleDatasource(),
);

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(ref.watch(localScheduleDatasourceProvider)),
);

final plannerServiceProvider = Provider<PlannerService>(
  (ref) => PlannerService(),
);

// ── Reactive schedule stream ────────────────────────────

/// Provides the computed weekly schedule as a stream.
/// Emits an initial value immediately, then re-emits whenever
/// any data in Hive changes (deviations added/removed, etc.).
final weeklyScheduleProvider = StreamProvider<ScheduleResult>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  final planner = ref.watch(plannerServiceProvider);

  // Build the initial schedule + listen for changes.
  final controller = StreamController<ScheduleResult>();

  Future<void> recompute() async {
    final blocks = await repo.getFixedBlocks();
    final targets = await repo.getTaskTargets();
    final deviations = await repo.getDeviations();

    final result = planner.computeWeeklySchedule(
      fixedBlocks: blocks,
      deviations: deviations,
      targets: targets,
    );

    controller.add(result);
  }

  // Emit initial schedule.
  recompute();

  // Watch for Hive box changes.
  final subscription = repo.watchAllChanges().listen((_) => recompute());

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

// ── Selected day state ──────────────────────────────────

/// Tracks which day is currently selected in the UI.
final selectedDayProvider = StateProvider<int>(
  (ref) => DateTime.now().weekday,
);

// ── Deviation actions ───────────────────────────────────

/// Provider for adding a deviation — triggers schedule recomputation
/// automatically via the Hive watch stream.
final addDeviationProvider = Provider<Future<void> Function(ScheduleDeviation)>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (deviation) => repo.addDeviation(deviation);
  },
);

/// Provider for removing a deviation.
final removeDeviationProvider = Provider<Future<void> Function(String)>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (id) => repo.removeDeviation(id);
  },
);

// ── Navigation & Extra Streams ──────────────────────────

/// Tracks the active bottom navigation tab in AppShell.
final currentNavigationIndexProvider = StateProvider<int>((ref) => 0);

/// Provides the active deviations list as a reactive stream.
final rawDeviationsProvider = StreamProvider<List<ScheduleDeviation>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  final controller = StreamController<List<ScheduleDeviation>>();

  Future<void> fetch() async {
    final list = await repo.getDeviations();
    controller.add(list);
  }

  fetch();
  final sub = repo.watchAllChanges().listen((_) => fetch());

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provides the floating task targets list as a reactive stream.
final rawTargetsProvider = StreamProvider<List<TaskTarget>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  final controller = StreamController<List<TaskTarget>>();

  Future<void> fetch() async {
    final list = await repo.getTaskTargets();
    controller.add(list);
  }

  fetch();
  final sub = repo.watchAllChanges().listen((_) => fetch());

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider for updating an existing task target.
final updateTaskTargetProvider = Provider<Future<void> Function(TaskTarget)>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (target) => repo.updateTaskTarget(target);
  },
);

/// Provider for adding a new task target.
final addTaskTargetProvider = Provider<Future<void> Function(TaskTarget)>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (target) => repo.addTaskTarget(target);
  },
);

/// Provider for removing a task target.
final removeTaskTargetProvider = Provider<Future<void> Function(String)>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (id) => repo.removeTaskTarget(id);
  },
);

/// Provider for toggling college attendance on a specific date.
final setCollegeStatusProvider = Provider<
    Future<void> Function(DateTime date,
        {required bool isAttending, OffDayStrategy strategy})>(
  (ref) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return (date,
            {required isAttending,
            strategy = OffDayStrategy.accelerateWeek}) =>
        repo.setCollegeStatusForDate(date,
            isAttending: isAttending, strategy: strategy);
  },
);


