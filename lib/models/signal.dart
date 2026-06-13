enum SignalType { strongBullish, bullish, neutral, bearish, strongBearish }

class AnalysisSignal {
  final String assetId;
  final SignalType signal;
  final double confidence; // 0-100
  final int indicatorsAgreeing; // cuántos de 8 apuntan a la misma dirección
  final int totalIndicators;

  // Core indicators
  final double rsi;
  final double macd;
  final double macdSignal;
  final double macdHistogram;

  // Trend
  final double sma20;
  final double sma50;
  final double sma200;
  final double ema9;

  // Bollinger Bands
  final double bbUpper;
  final double bbMiddle;
  final double bbLower;
  final double bbWidth; // volatilidad relativa

  // Oscillators
  final double stochRsi; // 0-100
  final double williamsR; // -100 a 0
  final double atr; // Average True Range
  final double adxApprox; // fuerza de tendencia 0-100

  // Volume analysis
  final double volumeRatio; // volumen actual / promedio 20d
  final String volumeSignal; // high_bull / high_bear / normal / low

  // Multi-timeframe (null si no disponible)
  final SignalType? tfDay;
  final SignalType? tfWeek;
  final SignalType? tfMonth;
  final int timeframeAgreement; // 0-3 cuántos TF coinciden con la señal principal

  // Sentiment
  final double fearGreedIndex;
  final String sentimentScore; // positive / neutral / negative

  // Metadata
  final List<String> reasons;
  final DateTime timestamp;

  AnalysisSignal({
    required this.assetId,
    required this.signal,
    required this.confidence,
    required this.indicatorsAgreeing,
    required this.totalIndicators,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.macdHistogram,
    required this.sma20,
    required this.sma50,
    required this.sma200,
    required this.ema9,
    required this.bbUpper,
    required this.bbMiddle,
    required this.bbLower,
    required this.bbWidth,
    required this.stochRsi,
    required this.williamsR,
    required this.atr,
    required this.adxApprox,
    required this.volumeRatio,
    required this.volumeSignal,
    this.tfDay,
    this.tfWeek,
    this.tfMonth,
    this.timeframeAgreement = 0,
    required this.fearGreedIndex,
    required this.sentimentScore,
    required this.reasons,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get signalLabel {
    switch (signal) {
      case SignalType.strongBullish:
        return 'ALCISTA FUERTE';
      case SignalType.bullish:
        return 'ALCISTA';
      case SignalType.neutral:
        return 'NEUTRAL';
      case SignalType.bearish:
        return 'BAJISTA';
      case SignalType.strongBearish:
        return 'BAJISTA FUERTE';
    }
  }

  int get signalColor {
    switch (signal) {
      case SignalType.strongBullish:
        return 0xFF00D4AA;
      case SignalType.bullish:
        return 0xFF4CAF50;
      case SignalType.neutral:
        return 0xFFFFB347;
      case SignalType.bearish:
        return 0xFFFF7043;
      case SignalType.strongBearish:
        return 0xFFFF6B6B;
    }
  }

  bool get isBullish =>
      signal == SignalType.bullish || signal == SignalType.strongBullish;

  bool get isBearish =>
      signal == SignalType.bearish || signal == SignalType.strongBearish;

  String get bbPosition {
    if (bbUpper == bbLower) return 'Normal';
    final range = bbUpper - bbLower;
    // Necesitamos el precio actual — esto se usa en UI con el asset
    return 'Normal';
  }

  String get volumeLabel {
    switch (volumeSignal) {
      case 'high_bull': return 'Volumen alto alcista';
      case 'high_bear': return 'Volumen alto bajista';
      case 'low': return 'Volumen bajo';
      default: return 'Volumen normal';
    }
  }

  AnalysisSignal copyWith({double? confidence}) => AnalysisSignal(
        assetId: assetId,
        signal: signal,
        confidence: confidence ?? this.confidence,
        indicatorsAgreeing: indicatorsAgreeing,
        totalIndicators: totalIndicators,
        rsi: rsi,
        macd: macd,
        macdSignal: macdSignal,
        macdHistogram: macdHistogram,
        sma20: sma20,
        sma50: sma50,
        sma200: sma200,
        ema9: ema9,
        bbUpper: bbUpper,
        bbMiddle: bbMiddle,
        bbLower: bbLower,
        bbWidth: bbWidth,
        stochRsi: stochRsi,
        williamsR: williamsR,
        atr: atr,
        adxApprox: adxApprox,
        volumeRatio: volumeRatio,
        volumeSignal: volumeSignal,
        tfDay: tfDay,
        tfWeek: tfWeek,
        tfMonth: tfMonth,
        timeframeAgreement: timeframeAgreement,
        fearGreedIndex: fearGreedIndex,
        sentimentScore: sentimentScore,
        reasons: reasons,
        timestamp: timestamp,
      );
}
