import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/signal_history_service.dart';
import '../models/signal.dart';
import '../theme/app_theme.dart';

class SignalHistoryScreen extends StatefulWidget {
  const SignalHistoryScreen({super.key});

  @override
  State<SignalHistoryScreen> createState() => _SignalHistoryScreenState();
}

class _SignalHistoryScreenState extends State<SignalHistoryScreen> {
  late Future<List<SignalHistoryEntry>> _future;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _future = SignalHistoryService().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de señales'),
        actions: [
          DropdownButton<int>(
            value: _days,
            dropdownColor: AppTheme.surface,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: const [
              DropdownMenuItem(value: 7, child: Text('7d')),
              DropdownMenuItem(value: 30, child: Text('30d')),
            ],
            onChanged: (v) => setState(() => _days = v!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<SignalHistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final cutoff = DateTime.now().subtract(Duration(days: _days));
          final all = (snap.data ?? [])
              .where((e) => e.timestamp.isAfter(cutoff))
              .toList();

          if (all.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: AppTheme.textSecondary, size: 56),
                  SizedBox(height: 12),
                  Text('Sin señales registradas aún',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 6),
                  Text('Las señales se guardan al abrir la app',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          // Stats
          final bullish = all.where((e) =>
              e.signal == SignalType.bullish || e.signal == SignalType.strongBullish).length;
          final bearish = all.where((e) =>
              e.signal == SignalType.bearish || e.signal == SignalType.strongBearish).length;
          final neutral = all.length - bullish - bearish;
          final highConf = all.where((e) => e.confidence >= 80).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats row
              Row(
                children: [
                  _StatCard('Total', '${all.length}', AppTheme.textPrimary),
                  const SizedBox(width: 8),
                  _StatCard('Alcistas', '$bullish', AppTheme.bullish),
                  const SizedBox(width: 8),
                  _StatCard('Bajistas', '$bearish', AppTheme.bearish),
                  const SizedBox(width: 8),
                  _StatCard('≥80% conf.', '$highConf', AppTheme.warning),
                ],
              ),
              const SizedBox(height: 8),
              // Distribution bar
              _DistributionBar(bullish: bullish, bearish: bearish, neutral: neutral, total: all.length),
              const SizedBox(height: 20),
              const Text('Señales recientes',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...all.map((e) => _HistoryTile(entry: e)),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _DistributionBar extends StatelessWidget {
  final int bullish, bearish, neutral, total;
  const _DistributionBar({required this.bullish, required this.bearish, required this.neutral, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Distribución de señales',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (bullish > 0)
                Expanded(flex: bullish, child: Container(height: 8, color: AppTheme.bullish)),
              if (neutral > 0)
                Expanded(flex: neutral, child: Container(height: 8, color: AppTheme.warning)),
              if (bearish > 0)
                Expanded(flex: bearish, child: Container(height: 8, color: AppTheme.bearish)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SignalHistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final color = Color(entry.signalColor);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.15),
            child: Text(entry.assetName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.assetName,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  '${DateFormat('dd/MM HH:mm').format(entry.timestamp)} · ${fmt.format(entry.price)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(entry.signalLabel,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text('${entry.confidence.toInt()}% conf.',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
