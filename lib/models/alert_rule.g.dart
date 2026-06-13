// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertRuleAdapter extends TypeAdapter<AlertRule> {
  @override
  final int typeId = 1;

  @override
  AlertRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertRule(
      id: fields[0] as String,
      assetId: fields[1] as String,
      assetSymbol: fields[2] as String,
      conditionIndex: fields[3] as int,
      targetValue: fields[4] as double,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      triggered: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AlertRule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assetId)
      ..writeByte(2)
      ..write(obj.assetSymbol)
      ..writeByte(3)
      ..write(obj.conditionIndex)
      ..writeByte(4)
      ..write(obj.targetValue)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.triggered);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
