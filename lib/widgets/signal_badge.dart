import 'package:flutter/material.dart';
import '../models/signal.dart';

class SignalBadge extends StatelessWidget {
  final AnalysisSignal signal;
  final bool large;

  const SignalBadge({super.key, required this.signal, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = Color(signal.signalColor);
    final fontSize = large ? 14.0 : 11.0;
    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SignalIcon(signal: signal.signal, size: fontSize + 2),
              const SizedBox(width: 4),
              Text(
                signal.signalLabel,
                style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (large) ...[
          const SizedBox(height: 10),
          _ConfidenceBar(confidence: signal.confidence, color: color),
        ],
      ],
    );
  }
}

class _SignalIcon extends StatelessWidget {
  final SignalType signal;
  final double size;
  const _SignalIcon({required this.signal, required this.size});

  @override
  Widget build(BuildContext context) {
    final icon = switch (signal) {
      SignalType.strongBullish => Icons.rocket_launch_rounded,
      SignalType.bullish => Icons.trending_up_rounded,
      SignalType.neutral => Icons.remove_rounded,
      SignalType.bearish => Icons.trending_down_rounded,
      SignalType.strongBearish => Icons.warning_rounded,
    };
    return Icon(icon, size: size + 2, color: Color(signal.color));
  }
}

class _ConfidenceBar extends StatefulWidget {
  final double confidence;
  final Color color;
  const _ConfidenceBar({required this.confidence, required this.color});

  @override
  State<_ConfidenceBar> createState() => _ConfidenceBarState();
}

class _ConfidenceBarState extends State<_ConfidenceBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0, end: widget.confidence / 100).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Confianza',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Text(
                '${(_anim.value * 100).toInt()}%',
                style: TextStyle(
                    color: widget.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LinearProgressIndicator(
              value: _anim.value,
              backgroundColor: widget.color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(widget.color),
              minHeight: 6,
            ),
          ),
        ),
      ],
    );
  }
}

extension on SignalType {
  int get color => switch (this) {
        SignalType.strongBullish => 0xFF00D4AA,
        SignalType.bullish => 0xFF26A69A,
        SignalType.neutral => 0xFF8B949E,
        SignalType.bearish => 0xFFEF5350,
        SignalType.strongBearish => 0xFFD32F2F,
      };
}
