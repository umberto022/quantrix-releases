// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PortfolioEntryAdapter extends TypeAdapter<PortfolioEntry> {
  @override
  final int typeId = 0;

  @override
  PortfolioEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PortfolioEntry(
      id: fields[0] as String,
      assetId: fields[1] as String,
      symbol: fields[2] as String,
      name: fields[3] as String,
      type: fields[4] as String,
      quantity: fields[5] as double,
      buyPrice: fields[6] as double,
      buyDate: fields[7] as DateTime,
      imageUrl: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PortfolioEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assetId)
      ..writeByte(2)
      ..write(obj.symbol)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.buyPrice)
      ..writeByte(7)
      ..write(obj.buyDate)
      ..writeByte(8)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
