import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_badge.dart';
import '../models/signal.dart';
import '../models/asset.dart';
import 'asset_detail_screen.dart';
import 'signal_history_screen.dart';
import 'ai_chat_screen.dart';

class SignalsScreen extends ConsumerStatefulWidget {
  const SignalsScreen({super.key});

  @override
  ConsumerState<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends ConsumerState<SignalsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) {
        ref.invalidate(topCryptosProvider);
        ref.invalidate(topSignalsProvider);
        ref.invalidate(fearGreedProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signalsAsync = ref.watch(topSignalsProvider);
    final fgiAsync = ref.watch(fearGreedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Mercado'),
        actions: [
          fgiAsync.when(
            data: (fgi) => _FgiChip(value: fgi),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppTheme.textSecondary),
            tooltip: 'Historial',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignalHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () {
              ref.invalidate(topCryptosProvider);
              ref.invalidate(topSignalsProvider);
              ref.invalidate(fearGreedProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Chat IA', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        ),
      ),
      body: signalsAsync.when(
        data: (items) => RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            ref.invalidate(topCryptosProvider);
            ref.invalidate(topSignalsProvider);
            ref.invalidate(fearGreedProvider);
            await ref.read(topSignalsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _SignalCard(asset: item.asset, signal: item.signal);
            },
          ),
        ),
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 8,
          itemBuilder: (_, __) => _ShimmerCard(),
        ),
        error: (e, _) => _ErrorRetry(
          message: e.toString().contains('SocketException') ||
                  e.toString().contains('connection')
              ? 'Sin conexión a internet'
              : 'Error cargando análisis',
          onRetry: () {
            ref.invalidate(topCryptosProvider);
            ref.invalidate(topSignalsProvider);
          },
        ),
      ),
    );
  }
}

class _FgiChip extends StatelessWidget {
  final double value;
  const _FgiChip({required this.value});

  String get _label {
    if (value < 20) return 'Miedo Ext.';
    if (value < 40) return 'Miedo';
    if (value < 60) return 'Neutral';
    if (value < 80) return 'Codicia';
    return 'Codicia Ext.';
  }

  Color get _color {
    if (value < 30) return AppTheme.bullish;
    if (value > 70) return AppTheme.bearish;
    return AppTheme.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${value.toInt()} · $_label',
        style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final Asset asset;
  final AnalysisSignal signal;
  final _repaintKey = GlobalKey();

  _SignalCard({required this.asset, required this.signal});

  Future<void> _shareSignal(BuildContext context) async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final signalLabel = signal.signalLabel;
      final text = '📊 ${asset.symbol.toUpperCase()} · Señal $signalLabel\n'
          'RSI: ${signal.rsi.toStringAsFixed(0)} · Confianza: ${signal.confidence.toInt()}%\n'
          '🔍 Análisis generado por Quantrix';

      await Share.shareXFiles(
        [XFile.fromData(bytes, name: '${asset.symbol}_signal.png', mimeType: 'image/png')],
        text: text,
      );
    } catch (_) {
      // Fallback: compartir solo texto
      await Share.share(
        '📊 ${asset.symbol.toUpperCase()} · ${signal.signalLabel}\n'
        'RSI: ${signal.rsi.toStringAsFixed(0)} · Confianza: ${signal.confidence.toInt()}%\n'
        '🔍 Análisis generado por Quantrix',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalColor = Color(signal.signalColor);
    final priceColor = asset.isBullish ? AppTheme.bullish : AppTheme.bearish;

    return RepaintBoundary(
      key: _repaintKey,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AssetDetailScreen(asset: asset)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: signal.confidence >= 80
                  ? signalColor.withValues(alpha: 0.4)
                  : AppTheme.cardBorder,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (asset.imageUrl != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(asset.imageUrl!),
                      radius: 18,
                      backgroundColor: AppTheme.surfaceLight,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(asset.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        Text(
                          '${asset.symbol.toUpperCase()} · ${asset.changePercent24h >= 0 ? '+' : ''}${asset.changePercent24h.toStringAsFixed(2)}% hoy',
                          style: TextStyle(color: priceColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  SignalBadge(signal: signal),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _shareSignal(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.share_outlined,
                          color: AppTheme.textSecondary, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MiniIndicator('RSI', signal.rsi.toStringAsFixed(0), _rsiColor(signal.rsi)),
                  _MiniIndicator(
                    'MACD',
                    signal.macdHistogram >= 0 ? 'â–²' : 'â–¼',
                    signal.macdHistogram >= 0 ? AppTheme.bullish : AppTheme.bearish,
                  ),
                  _MiniIndicator('StochRSI', signal.stochRsi.toStringAsFixed(0),
                      _stochColor(signal.stochRsi)),
                  _MiniIndicator('W%R', signal.williamsR.toStringAsFixed(0),
                      _williamsColor(signal.williamsR)),
                  const Spacer(),
                  _ConfidenceBar(confidence: signal.confidence, agreeing: signal.indicatorsAgreeing),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _rsiColor(double rsi) {
    if (rsi < 30) return AppTheme.bullish;
    if (rsi > 70) return AppTheme.bearish;
    return AppTheme.textSecondary;
  }

  Color _stochColor(double v) {
    if (v < 20) return AppTheme.bullish;
    if (v > 80) return AppTheme.bearish;
    return AppTheme.textSecondary;
  }

  Color _williamsColor(double v) {
    if (v < -80) return AppTheme.bullish;
    if (v > -20) return AppTheme.bearish;
    return AppTheme.textSecondary;
  }
}

class _MiniIndicator extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniIndicator(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double confidence;
  final int agreeing;
  const _ConfidenceBar({required this.confidence, required this.agreeing});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (confidence >= 85) {
      color = AppTheme.bullish;
    } else if (confidence >= 70) {
      color = AppTheme.warning;
    } else {
      color = AppTheme.textSecondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${confidence.toInt()}% conf.',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        Text('$agreeing/8 indicadores',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
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
        margin: const EdgeInsets.only(bottom: 10),
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_wifi_off, color: AppTheme.bearish, size: 56),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
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
