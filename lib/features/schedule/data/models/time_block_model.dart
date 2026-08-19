import 'package:hive_ce/hive.dart';

part 'time_block_model.g.dart';

@HiveType(typeId: 3)
enum TimeBlockTypeModel {
  @HiveField(0)
  fixed,

  @HiveField(1)
  floating,

  @HiveField(2)
  deviation,
}

@HiveType(typeId: 0)
class TimeBlockModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String label;

  @HiveField(2)
  late int dayOfWeek;

  @HiveField(3)
  late int startMinutes;

  @HiveField(4)
  late int endMinutes;

  @HiveField(5)
  late TimeBlockTypeModel typeModel;

  @HiveField(6)
  String? parentTargetId;

  TimeBlockModel();

  TimeBlockModel.create({
    required this.id,
    required this.label,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.typeModel,
    this.parentTargetId,
  });
}
