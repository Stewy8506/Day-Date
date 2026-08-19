// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_target_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskTargetModelAdapter extends TypeAdapter<TaskTargetModel> {
  @override
  final typeId = 1;

  @override
  TaskTargetModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskTargetModel()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..weeklyHours = (fields[2] as num).toDouble()
      ..priority = (fields[3] as num).toInt()
      ..affinityModel = fields[4] as TimeAffinityModel
      ..dailyCapHours = (fields[5] as num).toDouble();
  }

  @override
  void write(BinaryWriter writer, TaskTargetModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.weeklyHours)
      ..writeByte(3)
      ..write(obj.priority)
      ..writeByte(4)
      ..write(obj.affinityModel)
      ..writeByte(5)
      ..write(obj.dailyCapHours);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTargetModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeAffinityModelAdapter extends TypeAdapter<TimeAffinityModel> {
  @override
  final typeId = 5;

  @override
  TimeAffinityModel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TimeAffinityModel.morning;
      case 1:
        return TimeAffinityModel.afternoon;
      case 2:
        return TimeAffinityModel.lateNight;
      case 3:
        return TimeAffinityModel.flexible;
      default:
        return TimeAffinityModel.morning;
    }
  }

  @override
  void write(BinaryWriter writer, TimeAffinityModel obj) {
    switch (obj) {
      case TimeAffinityModel.morning:
        writer.writeByte(0);
      case TimeAffinityModel.afternoon:
        writer.writeByte(1);
      case TimeAffinityModel.lateNight:
        writer.writeByte(2);
      case TimeAffinityModel.flexible:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeAffinityModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
