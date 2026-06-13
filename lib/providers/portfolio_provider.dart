import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/portfolio_entry.dart';
import '../models/asset.dart';
import 'market_provider.dart';

final portfolioBoxProvider = Provider<Box<PortfolioEntry>>((ref) {
  return Hive.box<PortfolioEntry>('portfolio');
});

final portfolioProvider = StateNotifierProvider<PortfolioNotifier, List<PortfolioEntry>>((ref) {
  final box = ref.read(portfolioBoxProvider);
  return PortfolioNotifier(box);
});

class PortfolioNotifier extends StateNotifier<List<PortfolioEntry>> {
  final Box<PortfolioEntry> _box;

  PortfolioNotifier(this._box) : super(_box.values.toList());

  void add(PortfolioEntry entry) {
    _box.put(entry.id, entry);
    state = _box.values.toList();
  }

  void remove(String id) {
    _box.delete(id);
    state = _box.values.toList();
  }

  void update(PortfolioEntry entry) {
    _box.put(entry.id, entry);
    state = _box.values.toList();
  }
}

// Calcula el valor total del portfolio con precios actuales
final portfolioSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  final entries = ref.watch(portfolioProvider);
  final cryptos = await ref.watch(topCryptosProvider.future);

  double totalInvested = 0;
  double totalCurrent = 0;

  for (final entry in entries) {
    totalInvested += entry.invested;
    final asset = cryptos.cast<Asset?>().firstWhere(
          (a) => a?.id == entry.assetId || a?.symbol == entry.symbol,
          orElse: () => null,
        );
    if (asset != null) {
      totalCurrent += entry.currentValue(asset.price);
    } else {
      totalCurrent += entry.invested;
    }
  }

  return {
    'invested': totalInvested,
    'current': totalCurrent,
    'pnl': totalCurrent - totalInvested,
    'pnlPercent': totalInvested == 0 ? 0 : ((totalCurrent - totalInvested) / totalInvested) * 100,
  };
});
