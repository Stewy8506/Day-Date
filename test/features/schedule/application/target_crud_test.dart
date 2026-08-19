import 'package:flutter_test/flutter_test.dart';
import 'package:day_date/features/schedule/domain/entities/task_target.dart';

void main() {
  group('TaskTarget entity tests', () {
    test('copyWith properly updates properties', () {
      const original = TaskTarget(
        id: 'swe-1',
        name: 'SWE Roadmap',
        weeklyHours: 17.0,
        priority: 1,
        affinity: TimeAffinity.afternoon,
        dailyCapHours: 3.0,
      );

      final updated = original.copyWith(
        weeklyHours: 20.0,
        priority: 2,
        affinity: TimeAffinity.morning,
        dailyCapHours: 4.0,
      );

      expect(updated.id, 'swe-1');
      expect(updated.name, 'SWE Roadmap');
      expect(updated.weeklyHours, 20.0);
      expect(updated.priority, 2);
      expect(updated.affinity, TimeAffinity.morning);
      expect(updated.dailyCapHours, 4.0);
    });
  });
}
