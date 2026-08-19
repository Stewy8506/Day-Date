// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_completion_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskCompletionModelAdapter extends TypeAdapter<TaskCompletionModel> {
  @override
  final typeId = 7;

  @override
  TaskCompletionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskCompletionModel()
      ..id = fields[0] as String
      ..blockId = fields[1] as String
      ..targetId = fields[2] as String?
      ..dayOfWeek = (fields[3] as num).toInt()
      ..dateString = fields[4] as String
      ..isCompleted = fields[5] as bool
      ..scheduledMinutes = (fields[6] as num).toInt()
      ..actualMinutes = (fields[7] as num).toInt()
      ..updatedAt = fields[8] as DateTime;
  }

  @override
  void write(BinaryWriter writer, TaskCompletionModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.blockId)
      ..writeByte(2)
      ..write(obj.targetId)
      ..writeByte(3)
      ..write(obj.dayOfWeek)
      ..writeByte(4)
      ..write(obj.dateString)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.scheduledMinutes)
      ..writeByte(7)
      ..write(obj.actualMinutes)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCompletionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
