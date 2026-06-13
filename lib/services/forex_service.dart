import 'package:dio/dio.dart';
import '../models/asset.dart';

class ForexService {
  static const String _base = 'https://api.frankfurter.app';
  final Dio _dio = Dio();

  static const List<Map<String, String>> pairs = [
    {'from': 'EUR', 'to': 'USD', 'name': 'Euro / Dólar'},
    {'from': 'GBP', 'to': 'USD', 'name': 'Libra / Dólar'},
    {'from': 'USD', 'to': 'JPY', 'name': 'Dólar / Yen'},
    {'from': 'USD', 'to': 'CHF', 'name': 'Dólar / Franco Suizo'},
    {'from': 'AUD', 'to': 'USD', 'name': 'Dólar Aus / Dólar'},
    {'from': 'USD', 'to': 'CAD', 'name': 'Dólar / Dólar Can'},
    {'from': 'USD', 'to': 'DOP', 'name': 'Dólar / Peso Dom'},
    {'from': 'EUR', 'to': 'GBP', 'name': 'Euro / Libra'},
  ];

  Future<Asset> getRate(Map<String, String> pair) async {
    final from = pair['from']!;
    final to = pair['to']!;

    final res = await _dio.get('$_base/latest', queryParameters: {
      'from': from,
      'to': to,
    });

    final rate = (res.data['rates'][to] as num).toDouble();

    // Get yesterday's rate for change calculation
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    double prevRate = rate;
    try {
      final prevRes = await _dio.get('$_base/$dateStr', queryParameters: {
        'from': from,
        'to': to,
      });
      prevRate = (prevRes.data['rates'][to] as num).toDouble();
    } catch (_) {}

    final change = rate - prevRate;
    final changePct = prevRate != 0 ? (change / prevRate) * 100 : 0.0;

    return Asset(
      id: '${from}_$to'.toLowerCase(),
      symbol: '$from/$to',
      name: pair['name'] ?? '$from/$to',
      type: 'forex',
      price: rate,
      change24h: change,
      changePercent24h: changePct,
      volume24h: 0,
      marketCap: 0,
    );
  }

  Future<List<Asset>> getAllRates() async {
    final results = <Asset>[];
    for (final pair in pairs) {
      try {
        results.add(await getRate(pair));
      } catch (_) {}
    }
    return results;
  }

  Future<List<double>> getHistorical(String from, String to, {int days = 30}) async {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    final res = await _dio.get('$_base/$startStr..$endStr', queryParameters: {
      'from': from,
      'to': to,
    });

    final rates = res.data['rates'] as Map<String, dynamic>;
    return rates.values
        .map((e) => (e[to] as num).toDouble())
        .toList();
  }
}
