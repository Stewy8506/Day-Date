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
      ..extensionMinutes = (fields[7] as num?)?.toInt()
      ..offDayStrategyModel = fields[8] as OffDayStrategyModel?
      ..date = fields[9] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, ScheduleDeviationModel obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.extensionMinutes)
      ..writeByte(8)
      ..write(obj.offDayStrategyModel)
      ..writeByte(9)
      ..write(obj.date);
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
      case 2:
        return DeviationTypeModel.collegeCancellation;
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
      case DeviationTypeModel.collegeCancellation:
        writer.writeByte(2);
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

class OffDayStrategyModelAdapter extends TypeAdapter<OffDayStrategyModel> {
  @override
  final typeId = 6;

  @override
  OffDayStrategyModel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OffDayStrategyModel.accelerateWeek;
      case 1:
        return OffDayStrategyModel.restAndLeisure;
      default:
        return OffDayStrategyModel.accelerateWeek;
    }
  }

  @override
  void write(BinaryWriter writer, OffDayStrategyModel obj) {
    switch (obj) {
      case OffDayStrategyModel.accelerateWeek:
        writer.writeByte(0);
      case OffDayStrategyModel.restAndLeisure:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffDayStrategyModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
