/// Use case: Seed initial data on first launch.
library;

import 'package:day_date/features/schedule/domain/repositories/schedule_repository.dart';

class SeedInitialData {
  final ScheduleRepository _repository;

  SeedInitialData(this._repository);

  /// Seeds the database if this is the first launch.
  /// Returns true if seeding was performed, false if already seeded.
  Future<bool> call() async {
    final isFirst = await _repository.isFirstLaunch();
    if (!isFirst) return false;

    await _repository.seedIfEmpty();
    return true;
  }
}
