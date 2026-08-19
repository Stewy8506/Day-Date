import 'package:hive_ce/hive.dart';

part 'schedule_deviation_model.g.dart';

@HiveType(typeId: 4)
enum DeviationTypeModel {
  @HiveField(0)
  blockout,

  @HiveField(1)
  extension,

  @HiveField(2)
  collegeCancellation,
}

@HiveType(typeId: 6)
enum OffDayStrategyModel {
  @HiveField(0)
  accelerateWeek,

  @HiveField(1)
  restAndLeisure,
}

@HiveType(typeId: 2)
class ScheduleDeviationModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String label;

  @HiveField(2)
  late DeviationTypeModel typeModel;

  @HiveField(3)
  late int dayOfWeek;

  @HiveField(4)
  late int startMinutes;

  @HiveField(5)
  late int endMinutes;

  @HiveField(6)
  String? extendsBlockId;

  @HiveField(7)
  int? extensionMinutes;

  @HiveField(8)
  OffDayStrategyModel? offDayStrategyModel;

  @HiveField(9)
  DateTime? date;

  ScheduleDeviationModel();

  ScheduleDeviationModel.create({
    required this.id,
    required this.label,
    required this.typeModel,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.extendsBlockId,
    this.extensionMinutes,
    this.offDayStrategyModel,
    this.date,
  });
}
