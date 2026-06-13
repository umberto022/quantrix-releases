import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset.dart';
import '../services/forex_service.dart';
import '../services/analysis_service.dart';
import '../models/signal.dart';

final forexServiceProvider = Provider((_) => ForexService());

final forexRatesProvider = FutureProvider<List<Asset>>((ref) async {
  return ref.read(forexServiceProvider).getAllRates();
});

final forexSignalProvider = FutureProvider.family<AnalysisSignal, String>((ref, pairId) async {
  final parts = pairId.split('_');
  if (parts.length < 2) throw Exception('Invalid pair');
  final from = parts[0].toUpperCase();
  final to = parts[1].toUpperCase();

  final service = ref.read(forexServiceProvider);
  final analysis = AnalysisService();

  final prices = await service.getHistorical(from, to, days: 30);

  return analysis.generateSignal(
    assetId: pairId,
    prices: prices,
    fearGreedIndex: 50,
    changePercent24h: 0,
  );
});
