import 'package:flutter/material.dart';
import '../services/candle_service.dart';
import '../services/support_resistance_service.dart';
import '../theme/app_theme.dart';

class CandlestickChart extends StatelessWidget {
  final List<Candle> candles;
  final double height;
  final List<SRLevel> srLevels;
  final double? currentPrice;

  const CandlestickChart({
    super.key,
    required this.candles,
    this.height = 220,
    this.srLevels = const [],
    this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _CandlePainter(candles, srLevels: srLevels, currentPrice: currentPrice),
        size: Size.infinite,
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  final List<Candle> candles;
  final List<SRLevel> srLevels;
  final double? currentPrice;

  _CandlePainter(this.candles, {this.srLevels = const [], this.currentPrice});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final allPrices = candles.expand((c) => [c.high, c.low]).toList();
    final minPrice = allPrices.reduce((a, b) => a < b ? a : b);
    final maxPrice = allPrices.reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    if (priceRange == 0) return;

    final candleWidth = (size.width / candles.length) * 0.7;
    final gap = size.width / candles.length;

    final bullPaint = Paint()
      ..color = AppTheme.bullish
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final bearPaint = Paint()
      ..color = AppTheme.bearish
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final wickPaint = Paint()..strokeWidth = 1;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppTheme.cardBorder.withOpacity(0.5)
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // S/R level lines
    for (final level in srLevels) {
      final isSupport = level.type == SRType.support;
      final srPaint = Paint()
        ..color = (isSupport ? AppTheme.bullish : AppTheme.bearish)
            .withValues(alpha: 0.55)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      double toY2(double price) =>
          size.height - ((price - minPrice) / priceRange * size.height * 0.9) - size.height * 0.05;

      final ly = toY2(level.price);
      if (ly < 0 || ly > size.height) continue;

      // Dashed line
      const dashW = 6.0, gapW = 4.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, ly), Offset((x + dashW).clamp(0, size.width), ly), srPaint);
        x += dashW + gapW;
      }

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ${level.label} ',
          style: TextStyle(
            color: isSupport ? AppTheme.bullish : AppTheme.bearish,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(4, ly - 9));
    }

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = gap * i + gap / 2;
      final isBull = c.isBullish;
      final paint = isBull ? bullPaint : bearPaint;

      double toY(double price) =>
          size.height - ((price - minPrice) / priceRange * size.height * 0.9) - size.height * 0.05;

      final openY = toY(c.open);
      final closeY = toY(c.close);
      final highY = toY(c.high);
      final lowY = toY(c.low);

      // Mecha
      wickPaint.color = isBull ? AppTheme.bullish : AppTheme.bearish;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // Cuerpo
      final bodyTop = isBull ? closeY : openY;
      final bodyBot = isBull ? openY : closeY;
      final bodyHeight = (bodyBot - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.candles != candles || old.srLevels != srLevels;
}
