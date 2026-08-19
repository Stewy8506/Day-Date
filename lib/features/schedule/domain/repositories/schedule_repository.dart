/// Abstract interface for schedule data operations.
///
/// The domain layer depends on this interface; the data layer provides
/// the concrete implementation.
library;

import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/entities/task_completion.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';
import 'package:day_date/features/schedule/domain/entities/time_block.dart';

abstract class ScheduleRepository {
  /// Returns all baseline fixed blocks (college, gym, commute).
  Future<List<TimeBlock>> getFixedBlocks();

  /// Returns all floating task targets with their quotas.
  Future<List<TaskTarget>> getTaskTargets();

  /// Returns all active schedule deviations.
  Future<List<ScheduleDeviation>> getDeviations();

  /// Returns all task completion logs.
  Future<List<TaskCompletion>> getTaskCompletions();

  /// Persists or updates a task completion record.
  Future<void> setTaskCompletion(TaskCompletion completion);

  /// Removes a task completion record by ID.
  Future<void> removeTaskCompletion(String id);

  /// Persists a new deviation.
  Future<void> addDeviation(ScheduleDeviation deviation);

  /// Removes a deviation by ID.
  Future<void> removeDeviation(String id);

  /// Adds a new task target.
  Future<void> addTaskTarget(TaskTarget target);

  /// Updates an existing task target.
  Future<void> updateTaskTarget(TaskTarget target);

  /// Removes a task target by ID.
  Future<void> removeTaskTarget(String id);

  /// Seeds the database with initial fixed blocks and task targets
  /// if the database is empty (first launch).
  Future<void> seedIfEmpty();

  /// Returns true if this is the first launch (no data seeded yet).
  Future<bool> isFirstLaunch();

  /// Sets college attendance status for a specific calendar date.
  ///
  /// When [isAttending] is false, creates a `collegeCancellation` deviation
  /// for [date] with the given [strategy].
  /// When [isAttending] is true, removes any existing college cancellation
  /// deviation for that date, restoring the baseline schedule.
  Future<void> setCollegeStatusForDate(
    DateTime date, {
    required bool isAttending,
    OffDayStrategy strategy = OffDayStrategy.accelerateWeek,
  });

  /// Watches for any data changes (deviations added/removed, etc.)
  /// and emits a notification on each change.
  Stream<void> watchAllChanges();
}
