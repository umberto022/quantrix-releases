import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/forex_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_badge.dart';

class ForexScreen extends ConsumerStatefulWidget {
  const ForexScreen({super.key});

  @override
  ConsumerState<ForexScreen> createState() => _ForexScreenState();
}

class _ForexScreenState extends ConsumerState<ForexScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) ref.invalidate(forexRatesProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(forexRatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(forexRatesProvider),
          ),
        ],
      ),
      body: ratesAsync.when(
        data: (rates) => RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(forexRatesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rates.length,
            itemBuilder: (context, index) {
              final asset = rates[index];
              final signalAsync = ref.watch(forexSignalProvider(asset.id));
              final color = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;
              final fmt = NumberFormat('##0.0000');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          asset.symbol.split('/').first,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(asset.symbol,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                          Text(asset.name,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    signalAsync.when(
                      data: (signal) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SignalBadge(signal: signal),
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fmt.format(asset.price),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text(
                          '${asset.isBullish ? '+' : ''}${asset.changePercent24h.toStringAsFixed(3)}%',
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: AppTheme.surface,
            highlightColor: AppTheme.surfaceLight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.currency_exchange, color: AppTheme.bearish, size: 56),
              const SizedBox(height: 16),
              const Text('Error cargando tasas de cambio',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(forexRatesProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
