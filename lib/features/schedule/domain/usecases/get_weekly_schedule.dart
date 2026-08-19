/// Use case: Get the computed weekly schedule.
library;

import 'package:day_date/features/schedule/application/services/planner_service.dart';
import 'package:day_date/features/schedule/domain/repositories/schedule_repository.dart';

class GetWeeklySchedule {
  final ScheduleRepository _repository;
  final PlannerService _plannerService;

  GetWeeklySchedule(this._repository, this._plannerService);

  /// Fetches all data from the repository and computes the schedule.
  Future<ScheduleResult> call() async {
    final blocks = await _repository.getFixedBlocks();
    final targets = await _repository.getTaskTargets();
    final deviations = await _repository.getDeviations();

    return _plannerService.computeWeeklySchedule(
      fixedBlocks: blocks,
      deviations: deviations,
      targets: targets,
    );
  }
}
