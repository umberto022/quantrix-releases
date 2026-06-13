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
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            signal.signalLabel,
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
        ),
        if (large) ...[
          const SizedBox(height: 6),
          Text(
            'Confianza: ${signal.confidence.toStringAsFixed(0)}%',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
