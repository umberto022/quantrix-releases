import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_card.dart';
import '../widgets/heatmap_grid.dart';
import 'asset_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;
  final _searchController = TextEditingController();
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        ref.invalidate(topCryptosProvider);
        ref.invalidate(fearGreedProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cryptosAsync = ref.watch(topCryptosProvider);
    final fearGreedAsync = ref.watch(fearGreedProvider);
    const userName = 'Analista';

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(topCryptosProvider);
          ref.invalidate(fearGreedProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: _showSearch ? 60 : 110,
              floating: true,
              pinned: true,
              backgroundColor: AppTheme.background,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 12, right: 16),
                title: _showSearch
                    ? _SearchField(
                        controller: _searchController,
                        onChanged: (q) => setState(() => _query = q),
                        onClose: () {
                          setState(() {
                            _showSearch = false;
                            _query = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Quantrix',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              const SizedBox(width: 6),
                              Text('• Hola, $userName',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          fearGreedAsync.when(
                            data: (fgi) => _FearGreedChip(value: fgi),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
              ),
              actions: _showSearch
                  ? []
                  : [
                      IconButton(
                        icon: const Icon(Icons.search, color: AppTheme.textPrimary),
                        onPressed: () => setState(() => _showSearch = true),
                      ),
                    ],
            ),

            // Category chips
            if (!_showSearch)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: ['Crypto', 'Acciones', 'Forex', 'Top Señales'].map((label) {
                      final active = label == 'Crypto';
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.primary.withOpacity(0.15)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? AppTheme.primary : AppTheme.cardBorder,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                              color: active ? AppTheme.primary : AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Heatmap de mercado
            if (!_showSearch)
              const SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text('Heatmap 24h',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                    HeatmapGrid(),
                    SizedBox(height: 8),
                  ],
                ),
              ),

            // Assets list
            cryptosAsync.when(
              data: (assets) {
                final filtered = _query.isEmpty
                    ? assets
                    : assets
                        .where((a) =>
                            a.name.toLowerCase().contains(_query.toLowerCase()) ||
                            a.symbol.toLowerCase().contains(_query.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, color: AppTheme.textSecondary, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Sin resultados para "$_query"',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => AssetCard(
                      asset: filtered[index],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssetDetailScreen(asset: filtered[index]),
                        ),
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, __) => _ShimmerCard(),
                  childCount: 8,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorView(
                  message: e.toString().contains('SocketException') ||
                          e.toString().contains('HandshakeException')
                      ? 'Sin conexión a internet'
                      : 'Error cargando datos de mercado',
                  onRetry: () {
                    ref.invalidate(topCryptosProvider);
                    ref.invalidate(fearGreedProvider);
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Buscar activo...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              border: InputBorder.none,
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textSecondary, size: 18),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('Cancelar',
                style: TextStyle(color: AppTheme.primary, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.bearish, size: 56),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
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
    );
  }
}

class _FearGreedChip extends StatelessWidget {
  final double value;
  const _FearGreedChip({required this.value});

  String get label {
    if (value < 25) return 'Miedo extremo';
    if (value < 45) return 'Miedo';
    if (value < 55) return 'Neutral';
    if (value < 75) return 'Codicia';
    return 'Codicia extrema';
  }

  Color get color {
    if (value < 25) return AppTheme.bearish;
    if (value < 45) return AppTheme.warning;
    if (value < 55) return AppTheme.textSecondary;
    if (value < 75) return AppTheme.bullish;
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('Fear & Greed: ${value.toInt()} — $label',
            style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.surfaceLight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
