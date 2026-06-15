import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/asset.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AssetCard extends StatefulWidget {
  final Asset asset;
  final VoidCallback? onTap;

  const AssetCard({super.key, required this.asset, this.onTap});

  @override
  State<AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<AssetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() => _pressed = true);
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(_) {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.asset.isBullish ? AppTheme.bullish : AppTheme.bearish;
    final fmt = NumberFormat.compactCurrency(symbol: '\$');

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppTheme.surfaceLight
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _pressed
                    ? color.withValues(alpha: 0.3)
                    : AppTheme.cardBorder,
              ),
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Row(
              children: [
                _AssetIcon(asset: widget.asset),
                const SizedBox(width: 12),
                Expanded(child: _AssetInfo(asset: widget.asset)),
                if (widget.asset.sparkline.isNotEmpty) ...[
                  _Sparkline(sparkline: widget.asset.sparkline, color: color),
                  const SizedBox(width: 12),
                ],
                _PriceInfo(asset: widget.asset, color: color, fmt: fmt),
              ],
            ),
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
      return Hero(
        tag: 'asset-icon-${asset.id}',
        child: CircleAvatar(
          backgroundImage: NetworkImage(asset.imageUrl!),
          radius: 22,
          backgroundColor: AppTheme.surfaceLight,
        ),
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      child: Text(
        asset.symbol.substring(0, 1),
        style: const TextStyle(
            color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
      ),
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
          Text(
            asset.name,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                asset.symbol.toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              if (asset.marketCapRank != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '#${asset.marketCapRank}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
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
      width: 64,
      height: 38,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 1.8,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 0),
      ),
    );
  }
}

class _PriceInfo extends StatelessWidget {
  final Asset asset;
  final Color color;
  final NumberFormat fmt;
  const _PriceInfo(
      {required this.asset, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmt.format(asset.price),
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${asset.isBullish ? '▲' : '▼'} ${asset.changePercent24h.abs().toStringAsFixed(2)}%',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
