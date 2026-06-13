import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/signal.dart';

class SignalHistoryEntry {
  final String assetId;
  final String assetName;
  final SignalType signal;
  final double confidence;
  final double price;
  final DateTime timestamp;

  const SignalHistoryEntry({
    required this.assetId,
    required this.assetName,
    required this.signal,
    required this.confidence,
    required this.price,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'assetName': assetName,
        'signal': signal.index,
        'confidence': confidence,
        'price': price,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory SignalHistoryEntry.fromJson(Map<String, dynamic> j) => SignalHistoryEntry(
        assetId: j['assetId'] as String,
        assetName: j['assetName'] as String,
        signal: SignalType.values[j['signal'] as int],
        confidence: (j['confidence'] as num).toDouble(),
        price: (j['price'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int),
      );

  String get signalLabel {
    switch (signal) {
      case SignalType.strongBullish: return 'ALCISTA FUERTE';
      case SignalType.bullish: return 'ALCISTA';
      case SignalType.neutral: return 'NEUTRAL';
      case SignalType.bearish: return 'BAJISTA';
      case SignalType.strongBearish: return 'BAJISTA FUERTE';
    }
  }

  int get signalColor {
    switch (signal) {
      case SignalType.strongBullish: return 0xFF00D4AA;
      case SignalType.bullish: return 0xFF4CAF50;
      case SignalType.neutral: return 0xFFFFB347;
      case SignalType.bearish: return 0xFFFF7043;
      case SignalType.strongBearish: return 0xFFFF6B6B;
    }
  }
}

class SignalHistoryService {
  static const int _maxPerAsset = 20;
  static const String _prefix = 'signal_history_';

  Future<void> save(SignalHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${entry.assetId}';
    final raw = prefs.getStringList(key) ?? [];

    // Evitar duplicados muy cercanos en tiempo (< 10 min)
    if (raw.isNotEmpty) {
      final last = SignalHistoryEntry.fromJson(
          jsonDecode(raw.last) as Map<String, dynamic>);
      if (entry.timestamp.difference(last.timestamp).inMinutes < 10 &&
          entry.signal == last.signal) {
        return;
      }
    }

    raw.add(jsonEncode(entry.toJson()));
    if (raw.length > _maxPerAsset) raw.removeAt(0);
    await prefs.setStringList(key, raw);
  }

  Future<List<SignalHistoryEntry>> load(String assetId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_prefix$assetId') ?? [];
    return raw
        .map((s) => SignalHistoryEntry.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList()
        .reversed
        .toList(); // más reciente primero
  }

  Future<List<SignalHistoryEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final all = <SignalHistoryEntry>[];
    for (final key in keys) {
      final raw = prefs.getStringList(key) ?? [];
      for (final s in raw) {
        all.add(SignalHistoryEntry.fromJson(
            jsonDecode(s) as Map<String, dynamic>));
      }
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }
}
