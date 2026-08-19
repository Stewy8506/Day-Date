import 'package:hive_ce/hive.dart';

part 'task_target_model.g.dart';

@HiveType(typeId: 5)
enum TimeAffinityModel {
  @HiveField(0)
  morning,

  @HiveField(1)
  afternoon,

  @HiveField(2)
  lateNight,

  @HiveField(3)
  flexible,
}

@HiveType(typeId: 1)
class TaskTargetModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late double weeklyHours;

  @HiveField(3)
  late int priority;

  @HiveField(4)
  late TimeAffinityModel affinityModel;

  @HiveField(5)
  late double dailyCapHours;

  TaskTargetModel();

  TaskTargetModel.create({
    required this.id,
    required this.name,
    required this.weeklyHours,
    required this.priority,
    required this.affinityModel,
    required this.dailyCapHours,
  });
}
