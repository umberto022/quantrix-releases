import 'package:dio/dio.dart';
import '../models/asset.dart';

class StockService {
  static const String _base = 'https://www.alphavantage.co/query';
  // Free tier: 25 requests/day. Replace with your key from alphavantage.co
  static const String _apiKey = 'demo';
  final Dio _dio = Dio();

  Future<Asset?> getQuote(String symbol) async {
    try {
      final res = await _dio.get(_base, queryParameters: {
        'function': 'GLOBAL_QUOTE',
        'symbol': symbol,
        'apikey': _apiKey,
      });
      if (res.data['Global Quote'] == null || res.data['Global Quote'].isEmpty) return null;
      return Asset.fromAlphaVantage(symbol, res.data);
    } catch (_) {
      return null;
    }
  }

  Future<List<double>> getDailyClose(String symbol, {int limit = 60}) async {
    final res = await _dio.get(_base, queryParameters: {
      'function': 'TIME_SERIES_DAILY',
      'symbol': symbol,
      'apikey': _apiKey,
    });
    final series = res.data['Time Series (Daily)'] as Map<String, dynamic>?;
    if (series == null) return [];
    return series.values
        .take(limit)
        .map((e) => double.tryParse(e['4. close'] ?? '0') ?? 0)
        .toList()
        .reversed
        .toList();
  }

  // Popular stocks watchlist
  static const List<String> defaultStocks = ['AAPL', 'TSLA', 'MSFT', 'NVDA', 'AMZN', 'META'];
}
