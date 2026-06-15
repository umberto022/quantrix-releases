import 'dart:math' as math;
import '../models/signal.dart';

class AnalysisService {
  // ─── Core Helpers ────────────────────────────────────────────────────────

  double _avg(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  double _stdDev(List<double> v) {
    if (v.length < 2) return 0;
    final mean = _avg(v);
    final variance = v.map((x) => math.pow(x - mean, 2).toDouble()).reduce((a, b) => a + b) / v.length;
    return math.sqrt(variance);
  }

  // ─── 1. RSI — 14 períodos (Wilder's Smoothed) ────────────────────────────
  double calculateRSI(List<double> closes, {int period = 14}) {
    if (closes.length < period + 1) return 50.0;

    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final diff = closes[i] - closes[i - 1];
      if (diff > 0) {
        avgGain += diff;
      } else {
        avgLoss += diff.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    // Wilder's smoothing para el resto de períodos
    for (int i = period + 1; i < closes.length; i++) {
      final diff = closes[i] - closes[i - 1];
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? diff.abs() : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
    }

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  // ─── 2. EMA ───────────────────────────────────────────────────────────────
  double calculateEMA(List<double> prices, int period) {
    if (prices.length < period) return prices.isEmpty ? 0 : prices.last;
    final k = 2.0 / (period + 1);
    double ema = _avg(prices.sublist(0, period));
    for (int i = period; i < prices.length; i++) {
      ema = prices[i] * k + ema * (1 - k);
    }
    return ema;
  }

  // EMA sobre una lista ya procesada — para MACD signal line
  double _emaOf(List<double> values, int period) {
    if (values.length < period) return values.isEmpty ? 0 : values.last;
    final k = 2.0 / (period + 1);
    double ema = _avg(values.sublist(0, period));
    for (int i = period; i < values.length; i++) {
      ema = values[i] * k + ema * (1 - k);
    }
    return ema;
  }

  // ─── 3. MACD — EMA12 - EMA26, Signal = EMA9(MACD) ───────────────────────
  Map<String, double> calculateMACD(List<double> prices) {
    if (prices.length < 35) {
      return {'macd': 0, 'signal': 0, 'histogram': 0};
    }
    // Necesitamos generar la serie MACD punto a punto para calcular EMA9 correcto
    final macdSeries = <double>[];
    for (int i = 26; i <= prices.length; i++) {
      final slice = prices.sublist(0, i);
      final e12 = calculateEMA(slice, 12);
      final e26 = calculateEMA(slice, 26);
      macdSeries.add(e12 - e26);
    }
    final macdCurrent = macdSeries.last;
    final signalLine = _emaOf(macdSeries, 9);
    final histogram = macdCurrent - signalLine;
    return {'macd': macdCurrent, 'signal': signalLine, 'histogram': histogram};
  }

  // ─── 4. SMA ───────────────────────────────────────────────────────────────
  double calculateSMA(List<double> prices, int period) {
    if (prices.length < period) return prices.isEmpty ? 0 : prices.last;
    return _avg(prices.sublist(prices.length - period));
  }

  // ─── 5. Bollinger Bands (20, 2σ) ─────────────────────────────────────────
  Map<String, double> calculateBollingerBands(List<double> prices, {int period = 20, double multiplier = 2.0}) {
    if (prices.length < period) {
      final p = prices.isEmpty ? 0.0 : prices.last;
      return {'upper': p, 'middle': p, 'lower': p, 'width': 0};
    }
    final slice = prices.sublist(prices.length - period);
    final middle = _avg(slice);
    final std = _stdDev(slice);
    final upper = middle + multiplier * std;
    final lower = middle - multiplier * std;
    final width = middle > 0 ? (upper - lower) / middle * 100 : 0.0;
    return {'upper': upper, 'middle': middle, 'lower': lower, 'width': width};
  }

  // ─── 6. Stochastic RSI ────────────────────────────────────────────────────
  double calculateStochRSI(List<double> prices, {int period = 14}) {
    if (prices.length < period * 2) return 50.0;

    // Generar serie RSI completa
    final rsiSeries = <double>[];
    for (int i = period + 1; i <= prices.length; i++) {
      rsiSeries.add(calculateRSI(prices.sublist(0, i), period: period));
    }
    if (rsiSeries.length < period) return 50.0;

    final window = rsiSeries.sublist(rsiSeries.length - period);
    final minRsi = window.reduce(math.min);
    final maxRsi = window.reduce(math.max);
    if (maxRsi == minRsi) return 50.0;
    return ((rsiSeries.last - minRsi) / (maxRsi - minRsi)) * 100;
  }

  // ─── 7. Williams %R ───────────────────────────────────────────────────────
  double calculateWilliamsR(List<double> closes, {int period = 14}) {
    if (closes.length < period) return -50.0;
    final window = closes.sublist(closes.length - period);
    final highest = window.reduce(math.max);
    final lowest = window.reduce(math.min);
    if (highest == lowest) return -50.0;
    return ((highest - closes.last) / (highest - lowest)) * -100;
  }

  // ─── 8. ATR — Average True Range (14) ────────────────────────────────────
  // Con solo closes, aproximamos usando max(high-low) estimado desde precio
  double calculateATRApprox(List<double> closes, {int period = 14}) {
    if (closes.length < period + 1) return 0.0;
    final trValues = <double>[];
    for (int i = 1; i < closes.length; i++) {
      trValues.add((closes[i] - closes[i - 1]).abs());
    }
    // Wilder's smoothing
    double atr = _avg(trValues.sublist(0, period));
    for (int i = period; i < trValues.length; i++) {
      atr = (atr * (period - 1) + trValues[i]) / period;
    }
    return atr;
  }

  // ─── 9. ADX aproximado — fuerza de tendencia ─────────────────────────────
  double calculateADXApprox(List<double> prices, {int period = 14}) {
    if (prices.length < period * 2) return 25.0;
    // Usando dirección de EMAs como proxy de fuerza
    final ema5 = calculateEMA(prices, 5);
    final ema10 = calculateEMA(prices, 10);
    final ema20 = calculateEMA(prices, 20);
    final ema50 = calculateEMA(prices, 50);

    double strength = 0;
    // EMAs alineadas = tendencia fuerte
    final isBullishAlign = ema5 > ema10 && ema10 > ema20 && ema20 > ema50;
    final isBearishAlign = ema5 < ema10 && ema10 < ema20 && ema20 < ema50;

    if (isBullishAlign || isBearishAlign) {
      final atr = calculateATRApprox(prices, period: period);
      final recentMove = (prices.last - prices[prices.length - period]).abs();
      strength = atr > 0 ? (recentMove / (atr * period) * 100).clamp(20, 90) : 40;
    } else {
      strength = 20; // sin tendencia clara
    }
    return strength;
  }

  // ─── Análisis de Volumen ──────────────────────────────────────────────────
  Map<String, dynamic> analyzeVolume({
    required List<double> volumes,
    required double changePercent24h,
    int period = 20,
  }) {
    if (volumes.length < period) {
      return {'ratio': 1.0, 'signal': 'normal', 'vote': 0};
    }
    final avgVolume = _avg(volumes.sublist(volumes.length - period - 1, volumes.length - 1));
    final currentVolume = volumes.last;
    final ratio = avgVolume > 0 ? currentVolume / avgVolume : 1.0;

    String signal;
    int vote = 0;
    if (ratio > 1.5) {
      if (changePercent24h > 0) {
        signal = 'high_bull';
        vote = 1; // volumen alto con subida = confirmación alcista
      } else {
        signal = 'high_bear';
        vote = -1; // volumen alto con caída = confirmación bajista
      }
    } else if (ratio < 0.5) {
      signal = 'low';
      vote = 0; // volumen muy bajo = movimiento poco fiable
    } else {
      signal = 'normal';
      vote = 0;
    }

    return {'ratio': ratio, 'signal': signal, 'vote': vote};
  }

  // ─── Señal simple para multi-timeframe (sin volumen) ─────────────────────
  SignalType quickSignal(List<double> prices, double fgi) {
    if (prices.length < 15) return SignalType.neutral;
    final rsi = calculateRSI(prices);
    final macd = calculateMACD(prices);
    final sma20 = calculateSMA(prices, 20);
    final sma50 = calculateSMA(prices, 50);
    final price = prices.last;

    int score = 0;
    if (rsi < 35) {
      score += 2;
    } else if (rsi < 45) {
      score++;
    } else if (rsi > 65) {
      score -= 2;
    } else if (rsi > 55) {
      score--;
    }

    if (macd['macd']! > macd['signal']!) {
      score++;
    } else {
      score--;
    }

    if (price > sma20 && sma20 > sma50) {
      score++;
    } else if (price < sma20 && sma20 < sma50) {
      score--;
    }

    if (fgi < 35) {
      score++;
    } else if (fgi > 65) {
      score--;
    }

    if (score >= 3) return SignalType.strongBullish;
    if (score >= 1) return SignalType.bullish;
    if (score <= -3) return SignalType.strongBearish;
    if (score <= -1) return SignalType.bearish;
    return SignalType.neutral;
  }

  // ─── Main Signal Generator ────────────────────────────────────────────────
  AnalysisSignal generateSignal({
    required String assetId,
    required List<double> prices,
    required double fearGreedIndex,
    required double changePercent24h,
    List<double> volumes = const [],
    List<double> pricesWeek = const [],
    List<double> pricesMonth = const [],
  }) {
    if (prices.length < 15) {
      return _insufficientData(assetId, fearGreedIndex);
    }

    // Calcular todos los indicadores
    final rsi = calculateRSI(prices);
    final macdData = calculateMACD(prices);
    final sma20 = calculateSMA(prices, 20);
    final sma50 = calculateSMA(prices, 50);
    final sma200 = calculateSMA(prices, 200);
    final ema9 = calculateEMA(prices, 9);
    final bb = calculateBollingerBands(prices);
    final stochRsi = calculateStochRSI(prices);
    final williamsR = calculateWilliamsR(prices);
    final atr = calculateATRApprox(prices);
    final adx = calculateADXApprox(prices);
    final currentPrice = prices.last;

    // ── Votos direccionales (cada indicador da +1 alcista, -1 bajista, 0 neutral) ──
    int bullishVotes = 0;
    int bearishVotes = 0;
    final reasons = <String>[];

    // 1. RSI
    if (rsi < 30) {
      bullishVotes++;
      reasons.add('RSI ${rsi.toStringAsFixed(1)} — zona de sobreventa extrema (señal alcista)');
    } else if (rsi < 40) {
      bullishVotes++;
      reasons.add('RSI ${rsi.toStringAsFixed(1)} — presión compradora activa');
    } else if (rsi > 70) {
      bearishVotes++;
      reasons.add('RSI ${rsi.toStringAsFixed(1)} — zona de sobrecompra (señal bajista)');
    } else if (rsi > 60) {
      bearishVotes++;
      reasons.add('RSI ${rsi.toStringAsFixed(1)} — territorio sobrecomprado moderado');
    }

    // 2. MACD
    final macdVal = macdData['macd']!;
    final macdSig = macdData['signal']!;
    final macdHist = macdData['histogram']!;
    if (macdVal > macdSig && macdHist > 0) {
      bullishVotes++;
      reasons.add('MACD alcista — línea sobre señal con histograma positivo');
    } else if (macdVal < macdSig && macdHist < 0) {
      bearishVotes++;
      reasons.add('MACD bajista — línea bajo señal con histograma negativo');
    }

    // 3. Medias móviles (tendencia)
    bool smaBull = currentPrice > sma20 && sma20 > sma50;
    bool smaBear = currentPrice < sma20 && sma20 < sma50;
    if (smaBull) {
      bullishVotes++;
      reasons.add('Precio sobre SMA20 y SMA50 — tendencia alcista confirmada');
    } else if (smaBear) {
      bearishVotes++;
      reasons.add('Precio bajo SMA20 y SMA50 — tendencia bajista confirmada');
    }

    // SMA200 (tendencia de largo plazo — peso extra)
    if (prices.length >= 200) {
      if (currentPrice > sma200) {
        bullishVotes++;
        reasons.add('Precio sobre SMA200 — mercado en tendencia alcista de largo plazo');
      } else {
        bearishVotes++;
        reasons.add('Precio bajo SMA200 — mercado en tendencia bajista de largo plazo');
      }
    }

    // 4. Bollinger Bands
    final bbUpper = bb['upper']!;
    final bbLower = bb['lower']!;
    final bbMiddle = bb['middle']!;
    if (currentPrice <= bbLower) {
      bullishVotes++;
      reasons.add('Precio en banda inferior de Bollinger — posible reversión alcista');
    } else if (currentPrice >= bbUpper) {
      bearishVotes++;
      reasons.add('Precio en banda superior de Bollinger — posible sobrecalentamiento');
    } else if (currentPrice > bbMiddle) {
      bullishVotes++;
      reasons.add('Precio sobre media de Bollinger — momentum positivo');
    } else {
      bearishVotes++;
      reasons.add('Precio bajo media de Bollinger — momentum negativo');
    }

    // 5. Stochastic RSI
    if (stochRsi < 20) {
      bullishVotes++;
      reasons.add('Stoch RSI ${stochRsi.toStringAsFixed(1)} — sobreventa extrema en oscilador');
    } else if (stochRsi > 80) {
      bearishVotes++;
      reasons.add('Stoch RSI ${stochRsi.toStringAsFixed(1)} — sobrecompra extrema en oscilador');
    } else if (stochRsi < 40) {
      bullishVotes++;
      reasons.add('Stoch RSI ${stochRsi.toStringAsFixed(1)} — zona de acumulación');
    } else if (stochRsi > 60) {
      bearishVotes++;
      reasons.add('Stoch RSI ${stochRsi.toStringAsFixed(1)} — zona de distribución');
    }

    // 6. Williams %R
    if (williamsR < -80) {
      bullishVotes++;
      reasons.add('Williams %R ${williamsR.toStringAsFixed(1)} — sobreventa confirmada');
    } else if (williamsR > -20) {
      bearishVotes++;
      reasons.add('Williams %R ${williamsR.toStringAsFixed(1)} — sobrecompra confirmada');
    }

    // 7. Fear & Greed (contrarian)
    String sentiment;
    if (fearGreedIndex < 20) {
      bullishVotes++;
      sentiment = 'positive';
      reasons.add('Fear & Greed ${fearGreedIndex.toInt()}: Miedo extremo — oportunidad contraria histórica');
    } else if (fearGreedIndex < 35) {
      bullishVotes++;
      sentiment = 'positive';
      reasons.add('Fear & Greed ${fearGreedIndex.toInt()}: Miedo — sesgo contrario alcista');
    } else if (fearGreedIndex > 80) {
      bearishVotes++;
      sentiment = 'negative';
      reasons.add('Fear & Greed ${fearGreedIndex.toInt()}: Codicia extrema — riesgo de corrección elevado');
    } else if (fearGreedIndex > 65) {
      bearishVotes++;
      sentiment = 'negative';
      reasons.add('Fear & Greed ${fearGreedIndex.toInt()}: Codicia — mercado sobreextendido');
    } else {
      sentiment = 'neutral';
    }

    // 8. Cambio 24h + ADX fuerza
    if (changePercent24h > 3 && adx > 40) {
      bullishVotes++;
      reasons.add('Movimiento +${changePercent24h.toStringAsFixed(1)}% con tendencia fuerte (ADX ${adx.toStringAsFixed(0)})');
    } else if (changePercent24h < -3 && adx > 40) {
      bearishVotes++;
      reasons.add('Caída ${changePercent24h.toStringAsFixed(1)}% con tendencia fuerte (ADX ${adx.toStringAsFixed(0)})');
    }

    // 9. Análisis de volumen
    final volAnalysis = analyzeVolume(volumes: volumes, changePercent24h: changePercent24h);
    final volRatio = volAnalysis['ratio'] as double;
    final volSignal = volAnalysis['signal'] as String;
    final volVote = volAnalysis['vote'] as int;
    if (volVote > 0) {
      bullishVotes++;
      reasons.add('Volumen ${(volRatio * 100).toStringAsFixed(0)}% del promedio — confirma movimiento alcista');
    } else if (volVote < 0) {
      bearishVotes++;
      reasons.add('Volumen ${(volRatio * 100).toStringAsFixed(0)}% del promedio — confirma movimiento bajista');
    }

    // ── Multi-timeframe ────────────────────────────────────────────────────
    SignalType? tfDay, tfWeek, tfMonth;
    int tfAgreement = 0;
    if (prices.length >= 15) {
      tfDay = quickSignal(prices.length > 24 ? prices.sublist(prices.length - 24) : prices, fearGreedIndex);
    }
    if (pricesWeek.length >= 15) {
      tfWeek = quickSignal(pricesWeek, fearGreedIndex);
    }
    if (pricesMonth.length >= 15) {
      tfMonth = quickSignal(pricesMonth, fearGreedIndex);
    }

    // ── Determinar señal final ─────────────────────────────────────────────
    final totalVotes = bullishVotes + bearishVotes;
    final netVotes = bullishVotes - bearishVotes;
    const maxPossible = 9; // 8 indicadores + volumen

    SignalType signal;
    if (netVotes >= 4) {
      signal = SignalType.strongBullish;
    } else if (netVotes >= 2) {
      signal = SignalType.bullish;
    } else if (netVotes <= -4) {
      signal = SignalType.strongBearish;
    } else if (netVotes <= -2) {
      signal = SignalType.bearish;
    } else {
      signal = SignalType.neutral;
    }

    // ── Confianza multi-timeframe bonus ───────────────────────────────────
    final isBull = netVotes > 0;
    tfAgreement = [tfDay, tfWeek, tfMonth].where((tf) {
      if (tf == null) return false;
      if (isBull) return tf == SignalType.bullish || tf == SignalType.strongBullish;
      return tf == SignalType.bearish || tf == SignalType.strongBearish;
    }).length;

    if (tfAgreement >= 2) {
      reasons.add('Multi-timeframe: $tfAgreement/3 marcos temporales confirman la tendencia');
    }

    final agreeing = netVotes >= 0 ? bullishVotes : bearishVotes;
    final confidence = _calculateConfidence(
      agreeing: agreeing,
      total: math.max(totalVotes, 1),
      maxPossible: maxPossible,
      adxStrength: adx,
      signal: signal,
      rsi: rsi,
      macdHistogram: macdHist,
      tfAgreement: tfAgreement,
    );

    return AnalysisSignal(
      assetId: assetId,
      signal: signal,
      confidence: confidence,
      indicatorsAgreeing: agreeing,
      totalIndicators: maxPossible,
      rsi: rsi,
      macd: macdVal,
      macdSignal: macdSig,
      macdHistogram: macdHist,
      sma20: sma20,
      sma50: sma50,
      sma200: sma200,
      ema9: ema9,
      bbUpper: bbUpper,
      bbMiddle: bbMiddle,
      bbLower: bbLower,
      bbWidth: bb['width']!,
      stochRsi: stochRsi,
      williamsR: williamsR,
      atr: atr,
      adxApprox: adx,
      volumeRatio: volRatio,
      volumeSignal: volSignal,
      tfDay: tfDay,
      tfWeek: tfWeek,
      tfMonth: tfMonth,
      timeframeAgreement: tfAgreement,
      fearGreedIndex: fearGreedIndex,
      sentimentScore: sentiment,
      reasons: reasons,
    );
  }

  double _calculateConfidence({
    required int agreeing,
    required int total,
    required int maxPossible,
    required double adxStrength,
    required SignalType signal,
    required double rsi,
    required double macdHistogram,
    int tfAgreement = 0,
  }) {
    if (signal == SignalType.neutral) {
      return (45 + (agreeing / maxPossible * 15)).clamp(40, 60);
    }

    double base;
    if (agreeing >= 7) {
      base = 90;
    } else if (agreeing >= 6) {
      base = 82;
    } else if (agreeing >= 5) {
      base = 74;
    } else if (agreeing >= 4) {
      base = 66;
    } else {
      base = 58;
    }

    double adxBonus = 0;
    if (adxStrength > 60) {
      adxBonus = 5;
    } else if (adxStrength > 40) {
      adxBonus = 3;
    } else if (adxStrength < 20) {
      adxBonus = -4;
    }

    double rsiBonus = 0;
    if (rsi < 25 || rsi > 75) {
      rsiBonus = 3;
    } else if (rsi < 30 || rsi > 70) {
      rsiBonus = 1;
    }

    // Ajuste por MACD momentum
    double macdBonus = macdHistogram.abs() > 0 ? 2 : 0;

    // Bonus multi-timeframe
    final tfBonus = tfAgreement >= 3 ? 5.0 : tfAgreement == 2 ? 3.0 : 0.0;

    final raw = base + adxBonus + rsiBonus + macdBonus + tfBonus;
    return raw.clamp(55.0, 97.0);
  }

  AnalysisSignal _insufficientData(String assetId, double fearGreedIndex) {
    return AnalysisSignal(
      assetId: assetId,
      signal: SignalType.neutral,
      confidence: 45,
      indicatorsAgreeing: 0,
      totalIndicators: 9,
      rsi: 50,
      macd: 0,
      macdSignal: 0,
      macdHistogram: 0,
      sma20: 0,
      sma50: 0,
      sma200: 0,
      ema9: 0,
      bbUpper: 0,
      bbMiddle: 0,
      bbLower: 0,
      bbWidth: 0,
      stochRsi: 50,
      williamsR: -50,
      atr: 0,
      adxApprox: 0,
      volumeRatio: 1.0,
      volumeSignal: 'normal',
      fearGreedIndex: fearGreedIndex,
      sentimentScore: 'neutral',
      reasons: ['Datos insuficientes para análisis completo'],
    );
  }
}
