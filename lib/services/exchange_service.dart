import 'package:dio/dio.dart';

class ExchangePrice {
  final String exchange;
  final String emoji;
  final double buyPrice;
  final double sellPrice;

  const ExchangePrice({
    required this.exchange,
    required this.emoji,
    required this.buyPrice,
    required this.sellPrice,
  });

  double get midPrice => (buyPrice + sellPrice) / 2;
  double get spreadPct => buyPrice > 0 ? ((buyPrice - sellPrice) / buyPrice) * 100 : 0;
}

class ExchangeService {
  static final ExchangeService _i = ExchangeService._();
  factory ExchangeService() => _i;
  ExchangeService._();

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  Future<List<ExchangePrice>> getPrices(String symbol) async {
    final results = await Future.wait([
      _binance(symbol),
      _kucoin(symbol),
      _bybit(symbol),
      _okx(symbol),
      _gate(symbol),
    ]);
    return results.whereType<ExchangePrice>().toList();
  }

  Future<ExchangePrice?> _binance(String symbol) async {
    try {
      final r = await _dio.get(
        'https://api.binance.com/api/v3/ticker/bookTicker',
        queryParameters: {'symbol': '${symbol}USDT'},
      );
      final ask = double.parse(r.data['askPrice'].toString());
      final bid = double.parse(r.data['bidPrice'].toString());
      return ExchangePrice(exchange: 'Binance', emoji: '🟡', buyPrice: ask, sellPrice: bid);
    } catch (_) {
      return null;
    }
  }

  Future<ExchangePrice?> _kucoin(String symbol) async {
    try {
      final r = await _dio.get(
        'https://api.kucoin.com/api/v1/market/orderbook/level1',
        queryParameters: {'symbol': '$symbol-USDT'},
      );
      final data = r.data['data'];
      if (data == null) return null;
      final ask = double.parse(data['bestAsk'].toString());
      final bid = double.parse(data['bestBid'].toString());
      return ExchangePrice(exchange: 'KuCoin', emoji: '🟢', buyPrice: ask, sellPrice: bid);
    } catch (_) {
      return null;
    }
  }

  Future<ExchangePrice?> _bybit(String symbol) async {
    try {
      final r = await _dio.get(
        'https://api.bybit.com/v5/market/tickers',
        queryParameters: {'category': 'spot', 'symbol': '${symbol}USDT'},
      );
      final list = r.data['result']['list'] as List?;
      if (list == null || list.isEmpty) return null;
      final ask = double.parse(list[0]['ask1Price'].toString());
      final bid = double.parse(list[0]['bid1Price'].toString());
      return ExchangePrice(exchange: 'Bybit', emoji: '🟠', buyPrice: ask, sellPrice: bid);
    } catch (_) {
      return null;
    }
  }

  Future<ExchangePrice?> _okx(String symbol) async {
    try {
      final r = await _dio.get(
        'https://www.okx.com/api/v5/market/ticker',
        queryParameters: {'instId': '$symbol-USDT'},
      );
      final list = r.data['data'] as List?;
      if (list == null || list.isEmpty) return null;
      final ask = double.parse(list[0]['askPx'].toString());
      final bid = double.parse(list[0]['bidPx'].toString());
      return ExchangePrice(exchange: 'OKX', emoji: '🔵', buyPrice: ask, sellPrice: bid);
    } catch (_) {
      return null;
    }
  }

  Future<ExchangePrice?> _gate(String symbol) async {
    try {
      final r = await _dio.get(
        'https://api.gateio.ws/api/v4/spot/tickers',
        queryParameters: {'currency_pair': '${symbol}_USDT'},
      );
      final list = r.data as List?;
      if (list == null || list.isEmpty) return null;
      final ask = double.parse(list[0]['lowest_ask'].toString());
      final bid = double.parse(list[0]['highest_bid'].toString());
      return ExchangePrice(exchange: 'Gate.io', emoji: '⚫', buyPrice: ask, sellPrice: bid);
    } catch (_) {
      return null;
    }
  }
}
