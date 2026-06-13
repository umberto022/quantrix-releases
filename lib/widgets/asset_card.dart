import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/asset.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AssetCard extends StatelessWidget {
  final Asset asset;
  final VoidCallback? onTap;

  const AssetCard({super.key, required this.asset, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;
    final fmt = NumberFormat.compactCurrency(symbol: '\$');

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              _AssetIcon(asset: asset),
              const SizedBox(width: 12),
              Expanded(child: _AssetInfo(asset: asset)),
              if (asset.sparkline.isNotEmpty)
                _Sparkline(sparkline: asset.sparkline, color: color),
              const SizedBox(width: 12),
              _PriceInfo(asset: asset, color: color, fmt: fmt),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetIcon extends StatelessWidget {
  final Asset asset;
  const _AssetIcon({required this.asset});

  @override
  Widget build(BuildContext context) {
    if (asset.imageUrl != null) {
      return CircleAvatar(
        backgroundImage: NetworkImage(asset.imageUrl!),
        radius: 22,
        backgroundColor: AppTheme.surfaceLight,
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.surfaceLight,
      child: Text(asset.symbol.substring(0, 1),
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
    );
  }
}

class _AssetInfo extends StatelessWidget {
  final Asset asset;
  const _AssetInfo({required this.asset});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(asset.name,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(asset.symbol,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      );
}

class _Sparkline extends StatelessWidget {
  final List<double> sparkline;
  final Color color;
  const _Sparkline({required this.sparkline, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = sparkline
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return SizedBox(
      width: 60,
      height: 36,
      child: LineChart(LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      )),
    );
  }
}

class _PriceInfo extends StatelessWidget {
  final Asset asset;
  final Color color;
  final NumberFormat fmt;
  const _PriceInfo({required this.asset, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt.format(asset.price),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          Text(
            '${asset.isBullish ? '+' : ''}${asset.changePercent24h.toStringAsFixed(2)}%',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      );
}
