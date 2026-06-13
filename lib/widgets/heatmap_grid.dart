import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asset.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../screens/asset_detail_screen.dart';

class HeatmapGrid extends ConsumerWidget {
  const HeatmapGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cryptosAsync = ref.watch(topCryptosProvider);
    return cryptosAsync.when(
      data: (assets) => _buildGrid(context, assets),
      loading: () => const SizedBox(
          height: 100,
          child: Center(
              child: CircularProgressIndicator(
                  color: AppTheme.primary, strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildGrid(BuildContext context, List<Asset> assets) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.15,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: assets.length.clamp(0, 20),
      itemBuilder: (_, i) => _HeatmapCell(asset: assets[i]),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  final Asset asset;
  const _HeatmapCell({required this.asset});

  Color get _bgColor {
    final pct = asset.changePercent24h;
    if (pct >= 5) return const Color(0xFF00A876);
    if (pct >= 2) return const Color(0xFF00D4AA).withValues(alpha: 0.85);
    if (pct >= 0) return const Color(0xFF4CAF50).withValues(alpha: 0.55);
    if (pct >= -2) return const Color(0xFFFF7043).withValues(alpha: 0.55);
    if (pct >= -5) return const Color(0xFFFF5252).withValues(alpha: 0.8);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final pct = asset.changePercent24h;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset))),
      child: Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              asset.symbol,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
