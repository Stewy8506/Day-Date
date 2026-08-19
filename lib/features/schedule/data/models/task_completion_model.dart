import 'package:hive_ce/hive.dart';

part 'task_completion_model.g.dart';

@HiveType(typeId: 7)
class TaskCompletionModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String blockId;

  @HiveField(2)
  String? targetId;

  @HiveField(3)
  late int dayOfWeek;

  @HiveField(4)
  late String dateString;

  @HiveField(5)
  late bool isCompleted;

  @HiveField(6)
  late int scheduledMinutes;

  @HiveField(7)
  late int actualMinutes;

  @HiveField(8)
  late DateTime updatedAt;

  TaskCompletionModel();

  TaskCompletionModel.create({
    required this.id,
    required this.blockId,
    this.targetId,
    required this.dayOfWeek,
    required this.dateString,
    required this.isCompleted,
    required this.scheduledMinutes,
    required this.actualMinutes,
    required this.updatedAt,
  });
}
