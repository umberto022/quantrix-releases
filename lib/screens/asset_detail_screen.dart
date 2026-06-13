import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/asset.dart';
import '../models/signal.dart';
import '../providers/market_provider.dart';
import '../services/candle_service.dart';
import '../services/support_resistance_service.dart';
import '../services/signal_history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_badge.dart';
import '../widgets/candlestick_chart.dart';
import 'compare_screen.dart';

final _candleProvider = FutureProvider.family<List<Candle>, ({String id, Timeframe tf})>(
  (ref, args) => CandleService().getCryptoCandles(args.id, args.tf),
);

class AssetDetailScreen extends ConsumerStatefulWidget {
  final Asset asset;
  const AssetDetailScreen({super.key, required this.asset});

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen>
    with SingleTickerProviderStateMixin {
  Timeframe _tf = Timeframe.m1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final signalAsync = ref.watch(assetSignalProvider(asset.id));
    final candlesAsync = ref.watch(_candleProvider((id: asset.id, tf: _tf)));
    final srAsync = ref.watch(srLevelsProvider(asset.id));
    final srLevels = srAsync.valueOrNull ?? [];
    final color = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: asset.price < 1 ? 6 : 2);
    final fmtCompact = NumberFormat.compactCurrency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (asset.imageUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(asset.imageUrl!),
                radius: 14,
                backgroundColor: AppTheme.surfaceLight,
              ),
            const SizedBox(width: 8),
            Text(asset.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows, color: AppTheme.textSecondary),
            tooltip: 'Comparar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CompareScreen(assetA: asset)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Gráfica'),
            Tab(text: 'Análisis Completo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Gráfica ─────────────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmt.format(asset.price),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.bold)),
                        Row(children: [
                          Icon(
                            asset.isBullish ? Icons.arrow_upward : Icons.arrow_downward,
                            color: color,
                            size: 14,
                          ),
                          Text(
                            '${asset.isBullish ? '+' : ''}${asset.changePercent24h.toStringAsFixed(2)}% hoy',
                            style: TextStyle(color: color, fontSize: 14),
                          ),
                        ]),
                      ],
                    ),
                    signalAsync.when(
                      data: (s) => SignalBadge(signal: s, large: true),
                      loading: () => const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2)),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _TimeframeSelector(
                  selected: _tf,
                  onSelect: (tf) {
                    HapticFeedback.selectionClick();
                    setState(() => _tf = tf);
                  },
                ),
                const SizedBox(height: 12),
                candlesAsync.when(
                  data: (candles) => candles.isEmpty
                      ? const Center(
                          child: Text('Sin datos para este período',
                              style: TextStyle(color: AppTheme.textSecondary)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CandlestickChart(
                              candles: candles,
                              height: 220,
                              srLevels: srLevels,
                              currentPrice: asset.price,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CandleStat('Max',
                                    fmtCompact.format(candles.map((c) => c.high)
                                        .reduce((a, b) => a > b ? a : b)),
                                    AppTheme.bullish),
                                _CandleStat('Min',
                                    fmtCompact.format(candles.map((c) => c.low)
                                        .reduce((a, b) => a < b ? a : b)),
                                    AppTheme.bearish),
                                _CandleStat('Apertura',
                                    fmtCompact.format(candles.first.open),
                                    AppTheme.textSecondary),
                                _CandleStat('Cierre',
                                    fmtCompact.format(candles.last.close),
                                    AppTheme.textPrimary),
                              ],
                            ),
                          ],
                        ),
                  loading: () => const SizedBox(
                    height: 220,
                    child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                  error: (_, __) => const SizedBox(
                    height: 220,
                    child: Center(
                        child: Text('Error cargando gráfica',
                            style: TextStyle(color: AppTheme.bearish))),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionTitle('Datos de Mercado'),
                const SizedBox(height: 12),
                _FundamentalRow('Market Cap', fmtCompact.format(asset.marketCap)),
                _FundamentalRow('Volumen 24h', fmtCompact.format(asset.volume24h)),
                _FundamentalRow('Cambio 24h',
                    '${asset.change24h >= 0 ? '+' : ''}\$${asset.change24h.toStringAsFixed(2)}'),
                if (srLevels.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('Niveles S/R en gráfica'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: srLevels.map((l) => _SRChip(level: l, currentPrice: asset.price)).toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── Tab 2: Análisis Completo ───────────────────────────────────
          signalAsync.when(
            data: (signal) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de confianza
                  _ConfidenceHeader(signal: signal),
                  const SizedBox(height: 20),

                  // Momentum oscillators
                  _SectionTitle('Osciladores de Momentum'),
                  const SizedBox(height: 12),
                  _RsiBar(rsi: signal.rsi, label: 'RSI (14)'),
                  const SizedBox(height: 10),
                  _RsiBar(rsi: signal.stochRsi, label: 'Stochastic RSI'),
                  const SizedBox(height: 10),
                  _RsiBar(rsi: signal.williamsR + 100, label: 'Williams %R',
                    leftLabel: 'Sobrecompra', rightLabel: 'Sobreventa'),
                  const SizedBox(height: 20),

                  // MACD
                  _SectionTitle('MACD'),
                  const SizedBox(height: 12),
                  _MacdCard(signal: signal),
                  const SizedBox(height: 20),

                  // Bollinger Bands
                  _SectionTitle('Bandas de Bollinger (20, 2σ)'),
                  const SizedBox(height: 12),
                  _BollingerCard(signal: signal, currentPrice: asset.price),
                  const SizedBox(height: 20),

                  // Medias móviles
                  _SectionTitle('Medias Móviles'),
                  const SizedBox(height: 12),
                  _MaTable(signal: signal, currentPrice: asset.price, fmtCompact: fmtCompact),
                  const SizedBox(height: 20),

                  // Volatilidad y fuerza
                  _SectionTitle('Volatilidad y Fuerza de Tendencia'),
                  const SizedBox(height: 12),
                  Row(children: [
                    _InfoCard('ATR (14)', '\$${signal.atr.toStringAsFixed(2)}',
                        'Rango medio diario', AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    _InfoCard('ADX aprox.', '${signal.adxApprox.toStringAsFixed(0)}',
                        signal.adxApprox > 40 ? 'Tendencia fuerte' : 'Tendencia débil',
                        signal.adxApprox > 40 ? AppTheme.primary : AppTheme.warning),
                    const SizedBox(width: 8),
                    _InfoCard('Ancho BB', '${signal.bbWidth.toStringAsFixed(1)}%',
                        signal.bbWidth > 10 ? 'Alta volatilidad' : 'Baja volatilidad',
                        signal.bbWidth > 10 ? AppTheme.bearish : AppTheme.textSecondary),
                  ]),
                  const SizedBox(height: 20),

                  // Volumen
                  _SectionTitle('Análisis de Volumen'),
                  const SizedBox(height: 12),
                  _VolumeCard(signal: signal),
                  const SizedBox(height: 20),

                  // Multi-timeframe
                  if (signal.tfDay != null || signal.tfWeek != null || signal.tfMonth != null) ...[
                    _SectionTitle('Análisis Multi-Timeframe'),
                    const SizedBox(height: 12),
                    _MultiTimeframeCard(signal: signal),
                    const SizedBox(height: 20),
                  ],

                  // Soporte y Resistencia
                  _SRSection(assetId: asset.id, currentPrice: asset.price, fmt: fmtCompact),
                  const SizedBox(height: 20),

                  // Correlaciones
                  _CorrelationsSection(assetId: asset.id),
                  const SizedBox(height: 20),

                  // Razones del análisis
                  _SectionTitle('Análisis Detallado (${signal.indicatorsAgreeing}/${signal.totalIndicators} indicadores)'),
                  const SizedBox(height: 10),
                  ...signal.reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(
                            r.contains('alcista') || r.contains('sobreventa') || r.contains('Miedo')
                                ? Icons.trending_up
                                : r.contains('bajista') || r.contains('sobrecompra') || r.contains('Codicia')
                                    ? Icons.trending_down
                                    : Icons.remove,
                            color: r.contains('alcista') || r.contains('sobreventa') || r.contains('Miedo')
                                ? AppTheme.bullish
                                : r.contains('bajista') || r.contains('sobrecompra') || r.contains('Codicia')
                                    ? AppTheme.bearish
                                    : AppTheme.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(r,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 13))),
                        ]),
                      )),
                  const SizedBox(height: 24),

                  // Fear & Greed
                  _FearGreedCard(value: signal.fearGreedIndex),
                  const SizedBox(height: 20),

                  // Historial de señales
                  _SignalHistorySection(assetId: asset.id),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary)),
            error: (e, _) => Center(
              child: Text('Error en análisis: $e',
                  style: const TextStyle(color: AppTheme.bearish)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Secciones con providers propios ──────────────────────────────────────────

class _SRSection extends ConsumerWidget {
  final String assetId;
  final double currentPrice;
  final NumberFormat fmt;
  const _SRSection({required this.assetId, required this.currentPrice, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srAsync = ref.watch(srLevelsProvider(assetId));
    return srAsync.when(
      data: (levels) {
        if (levels.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Soporte y Resistencia'),
            const SizedBox(height: 12),
            _SRCard(levels: levels, currentPrice: currentPrice, fmt: fmt),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CorrelationsSection extends ConsumerWidget {
  final String assetId;
  const _CorrelationsSection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo mostrar correlaciones si no es BTC/ETH/BNB
    if (['bitcoin', 'ethereum', 'binancecoin'].contains(assetId)) {
      return const SizedBox.shrink();
    }
    final corrAsync = ref.watch(correlationProvider(assetId));
    return corrAsync.when(
      data: (corrs) {
        if (corrs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Correlaciones (90 días)'),
            const SizedBox(height: 12),
            _CorrelationsCard(correlations: corrs),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SignalHistorySection extends ConsumerWidget {
  final String assetId;
  const _SignalHistorySection({required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(signalHistoryProvider(assetId));
    return histAsync.when(
      data: (history) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Historial de Señales'),
            const SizedBox(height: 12),
            _SignalHistoryCard(history: history),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ── Widgets nuevos ────────────────────────────────────────────────────────────

class _VolumeCard extends StatelessWidget {
  final AnalysisSignal signal;
  const _VolumeCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final isHigh = signal.volumeRatio > 1.5;
    final isLow = signal.volumeRatio < 0.5;
    final volColor = isHigh
        ? (signal.isBullish ? AppTheme.bullish : AppTheme.bearish)
        : isLow
            ? AppTheme.textSecondary
            : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: volColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bar_chart_rounded, color: volColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signal.volumeLabel,
                    style: TextStyle(
                        color: volColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Volumen actual: ${signal.volumeRatio.toStringAsFixed(2)}x promedio 20d',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${signal.volumeRatio.toStringAsFixed(1)}x',
            style: TextStyle(
                color: volColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MultiTimeframeCard extends StatelessWidget {
  final AnalysisSignal signal;
  const _MultiTimeframeCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final tfs = <(String, SignalType?)>[
      ('Diario', signal.tfDay),
      ('Semanal', signal.tfWeek),
      ('Mensual', signal.tfMonth),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: tfs
                .where((t) => t.$2 != null)
                .map((t) => Expanded(child: _TFCell(label: t.$1, type: t.$2!)))
                .toList(),
          ),
          if (signal.timeframeAgreement > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${signal.timeframeAgreement}/3 timeframes coinciden — mayor confianza',
                    style: const TextStyle(color: AppTheme.primary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TFCell extends StatelessWidget {
  final String label;
  final SignalType type;
  const _TFCell({required this.label, required this.type});

  Color get _color {
    switch (type) {
      case SignalType.strongBullish: return AppTheme.bullish;
      case SignalType.bullish: return const Color(0xFF4CAF50);
      case SignalType.neutral: return AppTheme.warning;
      case SignalType.bearish: return AppTheme.bearish;
      case SignalType.strongBearish: return const Color(0xFFFF6B6B);
    }
  }

  String get _shortLabel {
    switch (type) {
      case SignalType.strongBullish: return '▲▲ Fuerte';
      case SignalType.bullish: return '▲ Alcista';
      case SignalType.neutral: return '— Neutral';
      case SignalType.bearish: return '▼ Bajista';
      case SignalType.strongBearish: return '▼▼ Fuerte';
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(_shortLabel,
              style: TextStyle(
                  color: _color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
}

class _SRCard extends StatelessWidget {
  final List<SRLevel> levels;
  final double currentPrice;
  final NumberFormat fmt;
  const _SRCard(
      {required this.levels, required this.currentPrice, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final supports = levels.where((l) => l.type == SRType.support).toList();
    final resistances =
        levels.where((l) => l.type == SRType.resistance).toList();

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
              const Expanded(
                  child: Text('Nivel',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12))),
              const SizedBox(
                  width: 80,
                  child: Text('Precio',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      textAlign: TextAlign.right)),
              const SizedBox(
                  width: 70,
                  child: Text('Dist.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                      textAlign: TextAlign.right)),
            ]),
          ),
          const Divider(color: AppTheme.cardBorder, height: 1),
          ...[...resistances.reversed, ...supports].map((l) {
            final isSupport = l.type == SRType.support;
            final color = isSupport ? AppTheme.bullish : AppTheme.bearish;
            final dist =
                ((l.price - currentPrice) / currentPrice * 100);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l.label,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(children: [
                        ...List.generate(l.strength, (_) =>
                          Icon(Icons.circle, color: color, size: 5)),
                        const SizedBox(width: 4),
                        Text(
                          isSupport ? 'Soporte' : 'Resistencia',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ]),
                    ),
                    SizedBox(
                        width: 80,
                        child: Text(fmt.format(l.price),
                            style: const TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12),
                            textAlign: TextAlign.right)),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${dist >= 0 ? '+' : ''}${dist.toStringAsFixed(1)}%',
                        style: TextStyle(color: color, fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ]),
                ),
                const Divider(color: AppTheme.cardBorder, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SRChip extends StatelessWidget {
  final SRLevel level;
  final double currentPrice;
  const _SRChip({required this.level, required this.currentPrice});

  @override
  Widget build(BuildContext context) {
    final isSupport = level.type == SRType.support;
    final color = isSupport ? AppTheme.bullish : AppTheme.bearish;
    final dist = ((level.price - currentPrice) / currentPrice * 100);
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${level.label} ${fmt.format(level.price)} (${dist >= 0 ? '+' : ''}${dist.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CorrelationsCard extends StatelessWidget {
  final Map<String, double> correlations;
  const _CorrelationsCard({required this.correlations});

  String _assetName(String id) {
    switch (id) {
      case 'bitcoin': return 'BTC';
      case 'ethereum': return 'ETH';
      case 'binancecoin': return 'BNB';
      default: return id.toUpperCase();
    }
  }

  String _label(double c) {
    if (c.abs() < 0.3) return 'Sin correlación';
    if (c.abs() < 0.6) return c > 0 ? 'Correlación positiva' : 'Correlación negativa';
    if (c.abs() < 0.8) return c > 0 ? 'Alta positiva' : 'Alta negativa';
    return c > 0 ? 'Muy alta positiva' : 'Muy alta negativa';
  }

  Color _color(double c) {
    if (c.abs() < 0.3) return AppTheme.textSecondary;
    if (c > 0) return AppTheme.primary;
    return AppTheme.bearish;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: correlations.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('vs ${_assetName(e.key)}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 13)),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      e.value.toStringAsFixed(2),
                      style: TextStyle(
                          color: _color(e.value),
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(_label(e.value),
                        style: TextStyle(color: _color(e.value), fontSize: 10)),
                  ]),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (e.value + 1) / 2,
                  backgroundColor: AppTheme.surfaceLight,
                  color: _color(e.value),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _SignalHistoryCard extends StatelessWidget {
  final List<SignalHistoryEntry> history;
  const _SignalHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final shown = history.take(5).toList();
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: shown.map((e) {
          final color = Color(e.signalColor);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.signalLabel,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Text(fmt.format(e.price),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('${e.confidence.toInt()}%',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  Text(dateFmt.format(e.timestamp),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ]),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Widgets de análisis existentes ───────────────────────────────────────────

class _ConfidenceHeader extends StatelessWidget {
  final AnalysisSignal signal;
  const _ConfidenceHeader({required this.signal});

  @override
  Widget build(BuildContext context) {
    final signalColor = Color(signal.signalColor);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: signalColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: signalColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(signal.signalLabel,
                    style: TextStyle(
                        color: signalColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${signal.indicatorsAgreeing} de ${signal.totalIndicators} indicadores confirman',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${signal.confidence.toInt()}%',
                  style: TextStyle(
                      color: signalColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const Text('confianza',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsiBar extends StatelessWidget {
  final double rsi;
  final String label;
  final String leftLabel;
  final String rightLabel;

  const _RsiBar({
    required this.rsi,
    required this.label,
    this.leftLabel = 'Sobrevendido',
    this.rightLabel = 'Sobrecomprado',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          Text(rsi.toStringAsFixed(1),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(leftLabel,
              style: const TextStyle(color: AppTheme.bullish, fontSize: 10)),
          Text(rightLabel,
              style: const TextStyle(color: AppTheme.bearish, fontSize: 10)),
        ]),
        const SizedBox(height: 3),
        Stack(children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [AppTheme.bullish, AppTheme.warning, AppTheme.bearish],
              ),
            ),
          ),
          Positioned(
            left: (rsi.clamp(0, 100) / 100 *
                    (MediaQuery.of(context).size.width - 72))
                .clamp(0, double.infinity),
            top: -3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _MacdCard extends StatelessWidget {
  final AnalysisSignal signal;
  const _MacdCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final histColor =
        signal.macdHistogram >= 0 ? AppTheme.bullish : AppTheme.bearish;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _MacdItem('MACD', signal.macd.toStringAsFixed(4),
                signal.macd >= 0 ? AppTheme.bullish : AppTheme.bearish)),
            Expanded(child: _MacdItem('Señal (EMA9)',
                signal.macdSignal.toStringAsFixed(4), AppTheme.textSecondary)),
            Expanded(child: _MacdItem('Histograma',
                signal.macdHistogram.toStringAsFixed(4), histColor)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(
              signal.macdHistogram >= 0 ? Icons.trending_up : Icons.trending_down,
              color: histColor, size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              signal.macdHistogram >= 0
                  ? 'Momentum alcista — MACD sobre línea señal'
                  : 'Momentum bajista — MACD bajo línea señal',
              style: TextStyle(color: histColor, fontSize: 12),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MacdItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacdItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
}

class _BollingerCard extends StatelessWidget {
  final AnalysisSignal signal;
  final double currentPrice;
  const _BollingerCard({required this.signal, required this.currentPrice});

  @override
  Widget build(BuildContext context) {
    final range = signal.bbUpper - signal.bbLower;
    final position =
        range > 0 ? (currentPrice - signal.bbLower) / range : 0.5;
    final fmtCompact = NumberFormat.compactCurrency(symbol: '\$');

    String posLabel;
    Color posColor;
    if (position <= 0.1) {
      posLabel = 'Bajo banda — sobreventa';
      posColor = AppTheme.bullish;
    } else if (position >= 0.9) {
      posLabel = 'Sobre banda — sobrecompra';
      posColor = AppTheme.bearish;
    } else if (position > 0.5) {
      posLabel = 'Zona alta';
      posColor = AppTheme.warning;
    } else {
      posLabel = 'Zona baja';
      posColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _MacdItem('Superior', fmtCompact.format(signal.bbUpper), AppTheme.bearish),
            _MacdItem('Media (SMA20)', fmtCompact.format(signal.bbMiddle), AppTheme.textSecondary),
            _MacdItem('Inferior', fmtCompact.format(signal.bbLower), AppTheme.bullish),
          ]),
          const SizedBox(height: 12),
          Stack(children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [AppTheme.bullish, AppTheme.surfaceLight, AppTheme.bearish],
                ),
              ),
            ),
            Positioned(
              left: (position.clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 76))
                  .clamp(0, double.infinity),
              top: -3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: posColor, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.circle, color: posColor, size: 8),
            const SizedBox(width: 6),
            Text(posLabel, style: TextStyle(color: posColor, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

class _MaTable extends StatelessWidget {
  final AnalysisSignal signal;
  final double currentPrice;
  final NumberFormat fmtCompact;
  const _MaTable(
      {required this.signal, required this.currentPrice, required this.fmtCompact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          _MaRow('EMA 9', signal.ema9, currentPrice, fmtCompact),
          const Divider(color: AppTheme.cardBorder, height: 1),
          _MaRow('SMA 20', signal.sma20, currentPrice, fmtCompact),
          const Divider(color: AppTheme.cardBorder, height: 1),
          _MaRow('SMA 50', signal.sma50, currentPrice, fmtCompact),
          if (signal.sma200 > 0) ...[
            const Divider(color: AppTheme.cardBorder, height: 1),
            _MaRow('SMA 200', signal.sma200, currentPrice, fmtCompact),
          ],
        ],
      ),
    );
  }
}

class _MaRow extends StatelessWidget {
  final String label;
  final double ma;
  final double currentPrice;
  final NumberFormat fmt;
  const _MaRow(this.label, this.ma, this.currentPrice, this.fmt);

  @override
  Widget build(BuildContext context) {
    if (ma <= 0) return const SizedBox.shrink();
    final isAbove = currentPrice > ma;
    final diff = ((currentPrice - ma) / ma * 100);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13))),
        Expanded(
            child: Text(fmt.format(ma),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 13))),
        Icon(
          isAbove ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: isAbove ? AppTheme.bullish : AppTheme.bearish,
          size: 20,
        ),
        Text(
          '${isAbove ? '+' : ''}${diff.toStringAsFixed(2)}%',
          style: TextStyle(
              color: isAbove ? AppTheme.bullish : AppTheme.bearish,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ]),
    );
  }
}

class _FearGreedCard extends StatelessWidget {
  final double value;
  const _FearGreedCard({required this.value});

  String get _label {
    if (value < 20) return 'Miedo Extremo';
    if (value < 40) return 'Miedo';
    if (value < 60) return 'Neutral';
    if (value < 80) return 'Codicia';
    return 'Codicia Extrema';
  }

  Color get _color {
    if (value < 30) return AppTheme.bullish;
    if (value > 70) return AppTheme.bearish;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(value.toInt().toString(),
            style:
                TextStyle(color: _color, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Fear & Greed Index',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(_label,
                  style: TextStyle(
                      color: _color, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                value < 40
                    ? 'Miedo histórico = oportunidad contraria'
                    : value > 70
                        ? 'Mercado sobreextendido — precaución'
                        : 'Sentimiento equilibrado',
                style:
                    const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ])),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  const _InfoCard(this.label, this.value, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _TimeframeSelector extends StatelessWidget {
  final Timeframe selected;
  final ValueChanged<Timeframe> onSelect;
  const _TimeframeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: Timeframe.values.map((tf) {
        final isSelected = tf == selected;
        return GestureDetector(
          onTap: () => onSelect(tf),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              tf.label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CandleStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CandleStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 10)),
          Text(value,
              style:
                  TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600));
}

class _FundamentalRow extends StatelessWidget {
  final String label;
  final String value;
  const _FundamentalRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}
