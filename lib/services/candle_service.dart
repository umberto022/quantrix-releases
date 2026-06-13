import 'package:dio/dio.dart';

class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  bool get isBullish => close >= open;
}

enum Timeframe { d1, w1, m1, m3, y1 }

extension TimeframeExt on Timeframe {
  String get label {
    switch (this) {
      case Timeframe.d1: return '1D';
      case Timeframe.w1: return '1S';
      case Timeframe.m1: return '1M';
      case Timeframe.m3: return '3M';
      case Timeframe.y1: return '1A';
    }
  }

  int get days {
    switch (this) {
      case Timeframe.d1: return 1;
      case Timeframe.w1: return 7;
      case Timeframe.m1: return 30;
      case Timeframe.m3: return 90;
      case Timeframe.y1: return 365;
    }
  }
}

class CandleService {
  final Dio _dio = Dio();

  Future<List<Candle>> getCryptoCandles(String coinId, Timeframe tf) async {
    // CoinGecko OHLC — gratis
    final res = await _dio.get(
      'https://api.coingecko.com/api/v3/coins/$coinId/ohlc',
      queryParameters: {'vs_currency': 'usd', 'days': tf.days},
    );

    return (res.data as List).map((e) {
      final ts = DateTime.fromMillisecondsSinceEpoch((e[0] as int));
      return Candle(
        time: ts,
        open: (e[1] as num).toDouble(),
        high: (e[2] as num).toDouble(),
        low: (e[3] as num).toDouble(),
        close: (e[4] as num).toDouble(),
        volume: 0,
      );
    }).toList();
  }
}
