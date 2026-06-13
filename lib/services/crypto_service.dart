import 'dart:async';
import 'package:dio/dio.dart';
import '../models/asset.dart';

class CryptoService {
  static const String _base = 'https://api.coingecko.com/api/v3';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 8),
  ));

  // Cache para evitar superar rate limits
  final Map<String, _CacheEntry<dynamic>> _cache = {};
  static const Duration _marketsCacheTtl = Duration(seconds: 25);
  static const Duration _ohlcCacheTtl = Duration(minutes: 3);
  static const Duration _chartCacheTtl = Duration(minutes: 5);
  static const Duration _fearGreedCacheTtl = Duration(minutes: 10);

  // ─── Retry con backoff exponencial ────────────────────────────────────────
  Future<T> _withRetry<T>(Future<T> Function() fn, {int maxAttempts = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on DioException catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;

        // 429 = rate limit — backoff más largo
        final isRateLimit = e.response?.statusCode == 429;
        final delay = Duration(seconds: isRateLimit ? 5 * attempt : attempt * 2);
        await Future.delayed(delay);
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  // ─── Cache helper ─────────────────────────────────────────────────────────
  T? _getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.time) > entry.ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  void _setCached(String key, dynamic data, Duration ttl) {
    _cache[key] = _CacheEntry(data, ttl);
  }

  // ─── API calls ─────────────────────────────────────────────────────────────

  Future<List<Asset>> getTopCryptos({int limit = 20}) async {
    final cacheKey = 'markets_$limit';
    final cached = _getCached<List<Asset>>(cacheKey);
    if (cached != null) return cached;

    return _withRetry(() async {
      final res = await _dio.get('$_base/coins/markets', queryParameters: {
        'vs_currency': 'usd',
        'order': 'market_cap_desc',
        'per_page': limit,
        'page': 1,
        'sparkline': true,
        'price_change_percentage': '24h',
      });
      final data = (res.data as List).map((e) => Asset.fromCoinGecko(e)).toList();
      _setCached(cacheKey, data, _marketsCacheTtl);
      return data;
    });
  }

  Future<List<double>> getOHLC(String coinId, {int days = 90}) async {
    final cacheKey = 'ohlc_${coinId}_$days';
    final cached = _getCached<List<double>>(cacheKey);
    if (cached != null) return cached;

    return _withRetry(() async {
      final res = await _dio.get('$_base/coins/$coinId/ohlc', queryParameters: {
        'vs_currency': 'usd',
        'days': days,
      });
      final data = (res.data as List).map((e) => (e[4] as num).toDouble()).toList();
      _setCached(cacheKey, data, _ohlcCacheTtl);
      return data;
    });
  }

  Future<Map<String, dynamic>> getCoinDetail(String coinId) async {
    return _withRetry(() async {
      final res = await _dio.get('$_base/coins/$coinId', queryParameters: {
        'localization': false,
        'tickers': false,
        'community_data': true,
        'developer_data': false,
      });
      return res.data as Map<String, dynamic>;
    });
  }

  Future<double> getFearGreedIndex() async {
    const cacheKey = 'fear_greed';
    final cached = _getCached<double>(cacheKey);
    if (cached != null) return cached;

    try {
      return await _withRetry(() async {
        final res = await Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )).get('https://api.alternative.me/fng/?limit=1');
        final value = double.tryParse(res.data['data'][0]['value'].toString()) ?? 50.0;
        _setCached(cacheKey, value, _fearGreedCacheTtl);
        return value;
      }, maxAttempts: 2);
    } catch (_) {
      return 50.0;
    }
  }

  /// Retorna {prices: [...], volumes: [...]} para N días
  Future<Map<String, List<double>>> getMarketChart(String coinId, {int days = 90}) async {
    final cacheKey = 'chart_${coinId}_$days';
    final cached = _getCached<Map<String, List<double>>>(cacheKey);
    if (cached != null) return cached;

    return _withRetry(() async {
      final res = await _dio.get('$_base/coins/$coinId/market_chart', queryParameters: {
        'vs_currency': 'usd',
        'days': days,
        'interval': days <= 7 ? 'hourly' : 'daily',
      });
      final prices = (res.data['prices'] as List)
          .map((e) => (e[1] as num).toDouble())
          .toList();
      final volumes = (res.data['total_volumes'] as List)
          .map((e) => (e[1] as num).toDouble())
          .toList();
      final data = {'prices': prices, 'volumes': volumes};
      _setCached(cacheKey, data, _chartCacheTtl);
      return data;
    });
  }

  /// Precios de múltiples activos para correlaciones
  Future<Map<String, List<double>>> getMultiplePrices(
      List<String> coinIds, {int days = 90}) async {
    final result = <String, List<double>>{};
    for (int i = 0; i < coinIds.length; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 300));
      try {
        final chart = await getMarketChart(coinIds[i], days: days);
        result[coinIds[i]] = chart['prices'] ?? [];
      } catch (_) {
        result[coinIds[i]] = [];
      }
    }
    return result;
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry<T> {
  final T data;
  final Duration ttl;
  final DateTime time;
  _CacheEntry(this.data, this.ttl) : time = DateTime.now();
}
