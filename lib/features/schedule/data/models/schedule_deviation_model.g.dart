// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_deviation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleDeviationModelAdapter
    extends TypeAdapter<ScheduleDeviationModel> {
  @override
  final typeId = 2;

  @override
  ScheduleDeviationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleDeviationModel()
      ..id = fields[0] as String
      ..label = fields[1] as String
      ..typeModel = fields[2] as DeviationTypeModel
      ..dayOfWeek = (fields[3] as num).toInt()
      ..startMinutes = (fields[4] as num).toInt()
      ..endMinutes = (fields[5] as num).toInt()
      ..extendsBlockId = fields[6] as String?
      ..extensionMinutes = (fields[7] as num?)?.toInt();
  }

  @override
  void write(BinaryWriter writer, ScheduleDeviationModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.typeModel)
      ..writeByte(3)
      ..write(obj.dayOfWeek)
      ..writeByte(4)
      ..write(obj.startMinutes)
      ..writeByte(5)
      ..write(obj.endMinutes)
      ..writeByte(6)
      ..write(obj.extendsBlockId)
      ..writeByte(7)
      ..write(obj.extensionMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleDeviationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DeviationTypeModelAdapter extends TypeAdapter<DeviationTypeModel> {
  @override
  final typeId = 4;

  @override
  DeviationTypeModel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DeviationTypeModel.blockout;
      case 1:
        return DeviationTypeModel.extension;
      default:
        return DeviationTypeModel.blockout;
    }
  }

  @override
  void write(BinaryWriter writer, DeviationTypeModel obj) {
    switch (obj) {
      case DeviationTypeModel.blockout:
        writer.writeByte(0);
      case DeviationTypeModel.extension:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviationTypeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
