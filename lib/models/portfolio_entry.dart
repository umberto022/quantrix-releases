import 'package:hive_flutter/hive_flutter.dart';

part 'portfolio_entry.g.dart';

@HiveType(typeId: 0)
class PortfolioEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String assetId;

  @HiveField(2)
  String symbol;

  @HiveField(3)
  String name;

  @HiveField(4)
  String type; // crypto, stock, forex

  @HiveField(5)
  double quantity;

  @HiveField(6)
  double buyPrice;

  @HiveField(7)
  DateTime buyDate;

  @HiveField(8)
  String? imageUrl;

  PortfolioEntry({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.type,
    required this.quantity,
    required this.buyPrice,
    required this.buyDate,
    this.imageUrl,
  });

  double get invested => quantity * buyPrice;

  double currentValue(double currentPrice) => quantity * currentPrice;

  double pnl(double currentPrice) => currentValue(currentPrice) - invested;

  double pnlPercent(double currentPrice) =>
      invested == 0 ? 0 : (pnl(currentPrice) / invested) * 100;
}
