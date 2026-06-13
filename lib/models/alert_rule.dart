import 'package:hive_flutter/hive_flutter.dart';

part 'alert_rule.g.dart';

enum AlertCondition { priceBelow, priceAbove, rsiBelow, rsiAbove, signalChange }

@HiveType(typeId: 1)
class AlertRule extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String assetId;

  @HiveField(2)
  String assetSymbol;

  @HiveField(3)
  int conditionIndex; // index of AlertCondition enum

  @HiveField(4)
  double targetValue;

  @HiveField(5)
  bool isActive;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  bool triggered;

  AlertRule({
    required this.id,
    required this.assetId,
    required this.assetSymbol,
    required this.conditionIndex,
    required this.targetValue,
    this.isActive = true,
    required this.createdAt,
    this.triggered = false,
  });

  AlertCondition get condition => AlertCondition.values[conditionIndex];

  String get description {
    switch (condition) {
      case AlertCondition.priceBelow:
        return '${assetSymbol} precio baja de \$${targetValue.toStringAsFixed(2)}';
      case AlertCondition.priceAbove:
        return '${assetSymbol} precio sube de \$${targetValue.toStringAsFixed(2)}';
      case AlertCondition.rsiBelow:
        return '${assetSymbol} RSI baja de ${targetValue.toStringAsFixed(0)}';
      case AlertCondition.rsiAbove:
        return '${assetSymbol} RSI sube de ${targetValue.toStringAsFixed(0)}';
      case AlertCondition.signalChange:
        return '${assetSymbol} señal cambia a COMPRA';
    }
  }
}
