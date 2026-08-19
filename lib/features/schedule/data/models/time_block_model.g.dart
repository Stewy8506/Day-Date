// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_block_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimeBlockModelAdapter extends TypeAdapter<TimeBlockModel> {
  @override
  final typeId = 0;

  @override
  TimeBlockModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeBlockModel()
      ..id = fields[0] as String
      ..label = fields[1] as String
      ..dayOfWeek = (fields[2] as num).toInt()
      ..startMinutes = (fields[3] as num).toInt()
      ..endMinutes = (fields[4] as num).toInt()
      ..typeModel = fields[5] as TimeBlockTypeModel
      ..parentTargetId = fields[6] as String?;
  }

  @override
  void write(BinaryWriter writer, TimeBlockModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.dayOfWeek)
      ..writeByte(3)
      ..write(obj.startMinutes)
      ..writeByte(4)
      ..write(obj.endMinutes)
      ..writeByte(5)
      ..write(obj.typeModel)
      ..writeByte(6)
      ..write(obj.parentTargetId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBlockModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TimeBlockTypeModelAdapter extends TypeAdapter<TimeBlockTypeModel> {
  @override
  final typeId = 3;

  @override
  TimeBlockTypeModel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TimeBlockTypeModel.fixed;
      case 1:
        return TimeBlockTypeModel.floating;
      case 2:
        return TimeBlockTypeModel.deviation;
      default:
        return TimeBlockTypeModel.fixed;
    }
  }

  @override
  void write(BinaryWriter writer, TimeBlockTypeModel obj) {
    switch (obj) {
      case TimeBlockTypeModel.fixed:
        writer.writeByte(0);
      case TimeBlockTypeModel.floating:
        writer.writeByte(1);
      case TimeBlockTypeModel.deviation:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBlockTypeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
