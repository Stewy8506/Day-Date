/// Use case: Add a schedule deviation.
library;

import 'package:day_date/features/schedule/domain/entities/schedule_deviation.dart';
import 'package:day_date/features/schedule/domain/repositories/schedule_repository.dart';

class AddDeviation {
  final ScheduleRepository _repository;

  AddDeviation(this._repository);

  /// Persists the deviation. The schedule will recompute automatically
  /// via the Hive watch stream in the provider layer.
  Future<void> call(ScheduleDeviation deviation) =>
      _repository.addDeviation(deviation);
}
