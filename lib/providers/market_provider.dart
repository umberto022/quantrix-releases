import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset.dart';
import '../models/signal.dart';
import '../services/crypto_service.dart';
import '../services/analysis_service.dart';
import '../services/support_resistance_service.dart';
import '../services/correlation_service.dart';
import '../services/signal_history_service.dart';

final cryptoServiceProvider = Provider((_) => CryptoService());
final analysisServiceProvider = Provider((_) => AnalysisService());
final srServiceProvider = Provider((_) => SupportResistanceService());
final correlationServiceProvider = Provider((_) => CorrelationService());
final signalHistoryServiceProvider = Provider((_) => SignalHistoryService());

final fearGreedProvider = FutureProvider<double>((ref) async {
  ref.keepAlive();
  return ref.read(cryptoServiceProvider).getFearGreedIndex();
});

final topCryptosProvider = FutureProvider<List<Asset>>((ref) async {
  ref.keepAlive();
  return ref.read(cryptoServiceProvider).getTopCryptos(limit: 20);
});

// Señal completa con volumen + multi-timeframe
final assetSignalProvider = FutureProvider.family<AnalysisSignal, String>((ref, assetId) async {
  final service = ref.read(cryptoServiceProvider);
  final analysis = ref.read(analysisServiceProvider);
  final histService = ref.read(signalHistoryServiceProvider);

  final results = await Future.wait([
    ref.watch(fearGreedProvider.future),
    service.getOHLC(assetId, days: 90),
    ref.watch(topCryptosProvider.future),
  ]);

  final fgi = results[0] as double;
  final prices = results[1] as List<double>;
  final assets = results[2] as List<Asset>;
  final asset = assets.firstWhere((a) => a.id == assetId, orElse: () => assets.first);

  // Obtener volumen y precios de múltiples timeframes en paralelo
  List<double> volumes = [];
  List<double> pricesWeek = [];
  List<double> pricesMonth = [];

  try {
    final chartData = await service.getMarketChart(assetId, days: 90);
    volumes = chartData['volumes'] ?? [];

    final weekChart = await service.getMarketChart(assetId, days: 7);
    pricesWeek = weekChart['prices'] ?? [];

    final monthChart = await service.getMarketChart(assetId, days: 30);
    pricesMonth = monthChart['prices'] ?? [];
  } catch (_) {}

  final signal = analysis.generateSignal(
    assetId: assetId,
    prices: prices,
    fearGreedIndex: fgi,
    changePercent24h: asset.changePercent24h,
    volumes: volumes,
    pricesWeek: pricesWeek,
    pricesMonth: pricesMonth,
  );

  // Guardar en historial
  histService.save(SignalHistoryEntry(
    assetId: assetId,
    assetName: asset.name,
    signal: signal.signal,
    confidence: signal.confidence,
    price: asset.price,
    timestamp: DateTime.now(),
  ));

  return signal;
});

// Top 10 señales para la pantalla principal
final topSignalsProvider = FutureProvider<List<({Asset asset, AnalysisSignal signal})>>((ref) async {
  final assets = await ref.watch(topCryptosProvider.future);
  final service = ref.read(cryptoServiceProvider);
  final analysis = ref.read(analysisServiceProvider);
  final fgi = await ref.watch(fearGreedProvider.future);

  final top10 = assets.take(10).toList();

  final signals = await Future.wait(
    top10.asMap().entries.map((entry) async {
      if (entry.key > 0) {
        await Future.delayed(Duration(milliseconds: entry.key * 200));
      }
      try {
        final prices = await service.getOHLC(entry.value.id, days: 90);
        List<double> volumes = [];
        try {
          final chart = await service.getMarketChart(entry.value.id, days: 30);
          volumes = chart['volumes'] ?? [];
        } catch (_) {}

        final signal = analysis.generateSignal(
          assetId: entry.value.id,
          prices: prices,
          fearGreedIndex: fgi,
          changePercent24h: entry.value.changePercent24h,
          volumes: volumes,
        );
        return (asset: entry.value, signal: signal);
      } catch (_) {
        final fallback = analysis.generateSignal(
          assetId: entry.value.id,
          prices: [],
          fearGreedIndex: fgi,
          changePercent24h: entry.value.changePercent24h,
        );
        return (asset: entry.value, signal: fallback);
      }
    }),
  );

  return signals;
});

// Screener: top 20 con señales para filtrar
final screenerProvider = FutureProvider<List<({Asset asset, AnalysisSignal signal})>>((ref) async {
  final assets = await ref.watch(topCryptosProvider.future);
  final service = ref.read(cryptoServiceProvider);
  final analysis = ref.read(analysisServiceProvider);
  final fgi = await ref.watch(fearGreedProvider.future);

  final results = await Future.wait(
    assets.asMap().entries.map((entry) async {
      if (entry.key > 0) {
        await Future.delayed(Duration(milliseconds: entry.key * 150));
      }
      try {
        final prices = await service.getOHLC(entry.value.id, days: 90);
        List<double> volumes = [];
        try {
          final chart = await service.getMarketChart(entry.value.id, days: 30);
          volumes = chart['volumes'] ?? [];
        } catch (_) {}
        final signal = analysis.generateSignal(
          assetId: entry.value.id,
          prices: prices,
          fearGreedIndex: fgi,
          changePercent24h: entry.value.changePercent24h,
          volumes: volumes,
        );
        return (asset: entry.value, signal: signal);
      } catch (_) {
        final fallback = analysis.generateSignal(
          assetId: entry.value.id,
          prices: [],
          fearGreedIndex: fgi,
          changePercent24h: entry.value.changePercent24h,
        );
        return (asset: entry.value, signal: fallback);
      }
    }),
  );

  return results;
});

// Correlaciones de un activo contra BTC, ETH, BNB
final correlationProvider = FutureProvider.family<Map<String, double>, String>((ref, assetId) async {
  final service = ref.read(cryptoServiceProvider);
  final corrService = ref.read(correlationServiceProvider);

  final references = ['bitcoin', 'ethereum', 'binancecoin'];
  final toFetch = references.where((id) => id != assetId).toList();

  final targetChart = await service.getMarketChart(assetId, days: 90);
  final targetPrices = targetChart['prices'] ?? [];

  final refPrices = await service.getMultiplePrices(toFetch, days: 90);

  return corrService.compareAgainst(targetPrices, refPrices);
});

// Historial de señales de un activo
final signalHistoryProvider = FutureProvider.family<List<SignalHistoryEntry>, String>((ref, assetId) async {
  return ref.read(signalHistoryServiceProvider).load(assetId);
});

// S/R levels para un activo
final srLevelsProvider = FutureProvider.family<List<SRLevel>, String>((ref, assetId) async {
  final service = ref.read(cryptoServiceProvider);
  final srService = ref.read(srServiceProvider);
  final prices = await service.getOHLC(assetId, days: 90);
  return srService.calculate(prices);
});
