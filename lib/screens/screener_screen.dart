import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../models/signal.dart';
import '../models/asset.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_badge.dart';
import 'asset_detail_screen.dart';

enum ScreenerFilter {
  all, rsiOversold, rsiOverbought, macdBull, macdBear,
  highVolume, strongBullish, strongBearish, highConfidence,
}

extension ScreenerFilterLabel on ScreenerFilter {
  String get label {
    switch (this) {
      case ScreenerFilter.all: return 'Todo';
      case ScreenerFilter.rsiOversold: return 'RSI Sobrevendido';
      case ScreenerFilter.rsiOverbought: return 'RSI Sobrecomprado';
      case ScreenerFilter.macdBull: return 'MACD Alcista';
      case ScreenerFilter.macdBear: return 'MACD Bajista';
      case ScreenerFilter.highVolume: return 'Volumen Alto';
      case ScreenerFilter.strongBullish: return 'Alcista Fuerte';
      case ScreenerFilter.strongBearish: return 'Bajista Fuerte';
      case ScreenerFilter.highConfidence: return 'Confianza ≥80%';
    }
  }

  bool matches(AnalysisSignal s) {
    switch (this) {
      case ScreenerFilter.all: return true;
      case ScreenerFilter.rsiOversold: return s.rsi < 35;
      case ScreenerFilter.rsiOverbought: return s.rsi > 65;
      case ScreenerFilter.macdBull: return s.macdHistogram > 0;
      case ScreenerFilter.macdBear: return s.macdHistogram < 0;
      case ScreenerFilter.highVolume: return s.volumeRatio > 1.5;
      case ScreenerFilter.strongBullish: return s.signal == SignalType.strongBullish;
      case ScreenerFilter.strongBearish: return s.signal == SignalType.strongBearish;
      case ScreenerFilter.highConfidence: return s.confidence >= 80;
    }
  }
}

class ScreenerScreen extends ConsumerStatefulWidget {
  const ScreenerScreen({super.key});

  @override
  ConsumerState<ScreenerScreen> createState() => _ScreenerScreenState();
}

class _ScreenerScreenState extends ConsumerState<ScreenerScreen> {
  ScreenerFilter _activeFilter = ScreenerFilter.all;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(screenerProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenerAsync = ref.watch(screenerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screener de Mercado'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(screenerProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: ScreenerFilter.values.map((f) {
                final active = f == _activeFilter;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppTheme.primary : AppTheme.cardBorder,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        color: active ? Colors.black : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(color: AppTheme.cardBorder, height: 1),
          Expanded(
            child: screenerAsync.when(
              data: (items) {
                final filtered = items
                    .where((item) => _activeFilter.matches(item.signal))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, color: AppTheme.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        Text('No hay activos con "${_activeFilter.label}"',
                            style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async => ref.invalidate(screenerProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _ScreenerRow(
                      asset: filtered[i].asset,
                      signal: filtered[i].signal,
                    ),
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: 8,
                itemBuilder: (_, __) => _ShimmerRow(),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.bearish, size: 48),
                    const SizedBox(height: 12),
                    const Text('Error cargando screener',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(screenerProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenerRow extends StatelessWidget {
  final Asset asset;
  final AnalysisSignal signal;
  const _ScreenerRow({required this.asset, required this.signal});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    final priceColor = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            if (asset.imageUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(asset.imageUrl!),
                radius: 16,
                backgroundColor: AppTheme.surfaceLight,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.symbol,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(fmt.format(asset.price),
                      style: TextStyle(color: priceColor, fontSize: 12)),
                ],
              ),
            ),
            // Mini indicadores clave
            _Chip('RSI ${signal.rsi.toStringAsFixed(0)}', _rsiColor(signal.rsi)),
            const SizedBox(width: 6),
            _Chip(
              signal.volumeRatio > 1.5
                  ? 'Vol ${(signal.volumeRatio).toStringAsFixed(1)}x'
                  : 'Vol normal',
              signal.volumeRatio > 1.5 ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            SignalBadge(signal: signal),
          ],
        ),
      ),
    );
  }

  Color _rsiColor(double rsi) {
    if (rsi < 35) return AppTheme.bullish;
    if (rsi > 65) return AppTheme.bearish;
    return AppTheme.textSecondary;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

class _ShimmerRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppTheme.surface,
        highlightColor: AppTheme.surfaceLight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 58,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}
