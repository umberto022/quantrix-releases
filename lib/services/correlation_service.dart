import 'dart:math' as math;

class CorrelationService {
  /// Correlación de Pearson entre dos series de precios.
  /// Retorna valor de -1 a 1.
  double pearson(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    if (n < 10) return 0;

    final x = a.sublist(a.length - n);
    final y = b.sublist(b.length - n);

    final meanX = x.reduce((s, v) => s + v) / n;
    final meanY = y.reduce((s, v) => s + v) / n;

    double num = 0, denomX = 0, denomY = 0;
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denomX += dx * dx;
      denomY += dy * dy;
    }

    final denom = math.sqrt(denomX * denomY);
    return denom == 0 ? 0 : (num / denom).clamp(-1.0, 1.0);
  }

  /// Retorna los retornos diarios normalizados (% cambio)
  List<double> toReturns(List<double> prices) {
    if (prices.length < 2) return [];
    final returns = <double>[];
    for (int i = 1; i < prices.length; i++) {
      if (prices[i - 1] != 0) {
        returns.add((prices[i] - prices[i - 1]) / prices[i - 1]);
      }
    }
    return returns;
  }

  String correlationLabel(double corr) {
    final abs = corr.abs();
    if (abs >= 0.8) return corr > 0 ? 'Muy alta positiva' : 'Muy alta negativa';
    if (abs >= 0.6) return corr > 0 ? 'Alta positiva' : 'Alta negativa';
    if (abs >= 0.4) return corr > 0 ? 'Moderada positiva' : 'Moderada negativa';
    if (abs >= 0.2) return corr > 0 ? 'Baja positiva' : 'Baja negativa';
    return 'Sin correlación';
  }

  /// Calcula correlaciones de un activo contra una lista de referencias
  Map<String, double> compareAgainst(
      List<double> target, Map<String, List<double>> references) {
    final targetReturns = toReturns(target);
    final result = <String, double>{};
    for (final entry in references.entries) {
      final refReturns = toReturns(entry.value);
      result[entry.key] = pearson(targetReturns, refReturns);
    }
    return result;
  }
}
