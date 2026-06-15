import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/asset.dart';
import '../providers/market_provider.dart';
import '../services/candle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/candlestick_chart.dart';
import '../widgets/signal_badge.dart';

final _compareCandlesProvider = FutureProvider.family<List<Candle>, String>(
  (ref, coinId) => CandleService().getCryptoCandles(coinId, Timeframe.m1),
);

class CompareScreen extends ConsumerStatefulWidget {
  final Asset assetA;
  final Asset? initialAssetB;

  const CompareScreen({super.key, required this.assetA, this.initialAssetB});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  Asset? _assetB;

  @override
  void initState() {
    super.initState();
    _assetB = widget.initialAssetB;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    final signalA = ref.watch(assetSignalProvider(widget.assetA.id));
    final signalB = _assetB != null ? ref.watch(assetSignalProvider(_assetB!.id)) : null;
    final candlesA = ref.watch(_compareCandlesProvider(widget.assetA.id));
    final candlesB = _assetB != null ? ref.watch(_compareCandlesProvider(_assetB!.id)) : null;
    final cryptosAsync = ref.watch(topCryptosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.assetA.symbol} vs ${_assetB?.symbol ?? '?'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector activo B
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: cryptosAsync.when(
                data: (assets) => DropdownButtonHideUnderline(
                  child: DropdownButton<Asset>(
                    value: _assetB,
                    hint: const Text('Seleccionar activo a comparar',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    dropdownColor: AppTheme.surface,
                    isExpanded: true,
                    items: assets
                        .where((a) => a.id != widget.assetA.id)
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Row(children: [
                                if (a.imageUrl != null)
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(a.imageUrl!),
                                    radius: 10,
                                    backgroundColor: AppTheme.surfaceLight,
                                  ),
                                const SizedBox(width: 8),
                                Text(a.name,
                                    style: const TextStyle(color: AppTheme.textPrimary)),
                              ]),
                            ))
                        .toList(),
                    onChanged: (a) => setState(() => _assetB = a),
                  ),
                ),
                loading: () => const Text('Cargando...',
                    style: TextStyle(color: AppTheme.textSecondary)),
                error: (_, __) => const Text('Error',
                    style: TextStyle(color: AppTheme.bearish)),
              ),
            ),
            const SizedBox(height: 20),

            // Side-by-side comparison
            if (_assetB != null) ...[
              Row(children: [
                Expanded(child: _AssetHeader(asset: widget.assetA, fmt: fmt)),
                const SizedBox(width: 12),
                Expanded(child: _AssetHeader(asset: _assetB!, fmt: fmt)),
              ]),
              const SizedBox(height: 16),

              // Señales lado a lado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: signalA.when(
                      data: (s) => _SignalColumn(signal: s),
                      loading: () => const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary)),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: signalB!.when(
                      data: (s) => _SignalColumn(signal: s),
                      loading: () => const Center(
                          child: CircularProgressIndicator(color: AppTheme.primary)),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Gráficas lado a lado
              const Text('Precio 1 Mes',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: candlesA.when(
                      data: (c) => _MiniChart(candles: c, color: AppTheme.primary),
                      loading: () => const SizedBox(height: 120,
                          child: Center(child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2))),
                      error: (_, __) => const SizedBox(height: 120),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: candlesB!.when(
                      data: (c) => _MiniChart(candles: c, color: AppTheme.warning),
                      loading: () => const SizedBox(height: 120,
                          child: Center(child: CircularProgressIndicator(
                              color: AppTheme.warning, strokeWidth: 2))),
                      error: (_, __) => const SizedBox(height: 120),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Comparación de indicadores en tabla
              _IndicatorTable(
                assetA: widget.assetA,
                assetB: _assetB!,
                signalA: signalA.valueOrNull,
                signalB: signalB.valueOrNull,
              ),
            ] else ...[
              const SizedBox(height: 60),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.compare_arrows, color: AppTheme.textSecondary, size: 56),
                    SizedBox(height: 16),
                    Text('Selecciona un activo para comparar',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetHeader extends StatelessWidget {
  final Asset asset;
  final NumberFormat fmt;
  const _AssetHeader({required this.asset, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (asset.imageUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(asset.imageUrl!),
                radius: 12,
                backgroundColor: AppTheme.surfaceLight,
              ),
            const SizedBox(width: 8),
            Text(asset.symbol,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 6),
          Text(fmt.format(asset.price),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          Text(
            '${asset.isBullish ? '+' : ''}${asset.changePercent24h.toStringAsFixed(2)}%',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SignalColumn extends StatelessWidget {
  final dynamic signal;
  const _SignalColumn({required this.signal});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SignalBadge(signal: signal, large: true),
        const SizedBox(height: 8),
        Text('${signal.indicatorsAgreeing}/${signal.totalIndicators} indicadores',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<Candle> candles;
  final Color color;
  const _MiniChart({required this.candles, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: CandlestickChart(candles: candles, height: 120),
    );
  }
}

class _IndicatorTable extends StatelessWidget {
  final Asset assetA;
  final Asset assetB;
  final dynamic signalA;
  final dynamic signalB;
  const _IndicatorTable(
      {required this.assetA, required this.assetB, this.signalA, this.signalB});

  @override
  Widget build(BuildContext context) {
    if (signalA == null || signalB == null) return const SizedBox.shrink();

    final rows = [
      ('RSI', signalA.rsi.toStringAsFixed(1), signalB.rsi.toStringAsFixed(1)),
      ('Stoch RSI', signalA.stochRsi.toStringAsFixed(1), signalB.stochRsi.toStringAsFixed(1)),
      ('Williams %R', signalA.williamsR.toStringAsFixed(1), signalB.williamsR.toStringAsFixed(1)),
      ('ADX (fuerza)', signalA.adxApprox.toStringAsFixed(0), signalB.adxApprox.toStringAsFixed(0)),
      ('Confianza', '${signalA.confidence.toInt()}%', '${signalB.confidence.toInt()}%'),
      ('Volumen', '${signalA.volumeRatio.toStringAsFixed(2)}x', '${signalB.volumeRatio.toStringAsFixed(2)}x'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Expanded(child: Text('Indicador',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
              SizedBox(width: 70,
                  child: Text(assetA.symbol,
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center)),
              SizedBox(width: 70,
                  child: Text(assetB.symbol,
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      textAlign: TextAlign.center)),
            ]),
          ),
          const Divider(color: AppTheme.cardBorder, height: 1),
          ...rows.map((row) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text(row.$1,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13))),
                      SizedBox(width: 70,
                          child: Text(row.$2,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13),
                              textAlign: TextAlign.center)),
                      SizedBox(width: 70,
                          child: Text(row.$3,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13),
                              textAlign: TextAlign.center)),
                    ]),
                  ),
                  const Divider(color: AppTheme.cardBorder, height: 1),
                ],
              )),
        ],
      ),
    );
  }
}
