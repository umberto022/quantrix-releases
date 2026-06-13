import 'dart:math' as math;

class SRLevel {
  final double price;
  final SRType type;
  final int strength; // 1-5, cuántas veces fue tocado
  final String label;

  const SRLevel({
    required this.price,
    required this.type,
    required this.strength,
    required this.label,
  });
}

enum SRType { support, resistance }

class SupportResistanceService {
  /// Detecta niveles de soporte y resistencia desde una lista de cierres OHLC.
  /// Usa mínimos/máximos locales con ventana de lookback.
  List<SRLevel> calculate(List<double> closes, {int lookback = 5, int maxLevels = 6}) {
    if (closes.length < lookback * 2 + 1) return [];

    final supports = <double>[];
    final resistances = <double>[];

    for (int i = lookback; i < closes.length - lookback; i++) {
      final window = closes.sublist(i - lookback, i + lookback + 1);
      final center = closes[i];
      final minW = window.reduce(math.min);
      final maxW = window.reduce(math.max);

      // Mínimo local = soporte
      if (center == minW) supports.add(center);
      // Máximo local = resistencia
      if (center == maxW) resistances.add(center);
    }

    final currentPrice = closes.last;

    // Cluster niveles cercanos (dentro del 1.5%)
    final clusteredSupports = _cluster(supports, currentPrice);
    final clusteredResistances = _cluster(resistances, currentPrice);

    // Filtrar: soporte = bajo precio actual, resistencia = sobre precio actual
    final levels = <SRLevel>[];

    for (final entry in clusteredSupports.entries) {
      if (entry.key < currentPrice * 0.995) {
        levels.add(SRLevel(
          price: entry.key,
          type: SRType.support,
          strength: entry.value.clamp(1, 5),
          label: 'S${levels.where((l) => l.type == SRType.support).length + 1}',
        ));
      }
    }

    for (final entry in clusteredResistances.entries) {
      if (entry.key > currentPrice * 1.005) {
        levels.add(SRLevel(
          price: entry.key,
          type: SRType.resistance,
          strength: entry.value.clamp(1, 5),
          label: 'R${levels.where((l) => l.type == SRType.resistance).length + 1}',
        ));
      }
    }

    // Ordenar por proximidad al precio actual y limitar
    levels.sort((a, b) =>
        (a.price - currentPrice).abs().compareTo((b.price - currentPrice).abs()));

    return levels.take(maxLevels).toList();
  }

  Map<double, int> _cluster(List<double> prices, double reference) {
    if (prices.isEmpty) return {};
    final result = <double, int>{};

    for (final p in prices) {
      bool merged = false;
      for (final key in result.keys.toList()) {
        if ((key - p).abs() / reference < 0.015) {
          // Dentro del 1.5% → mismo nivel
          final avg = (key * result[key]! + p) / (result[key]! + 1);
          final count = result.remove(key)!;
          result[avg] = count + 1;
          merged = true;
          break;
        }
      }
      if (!merged) result[p] = 1;
    }

    return result;
  }

  /// Determina si el precio está en zona de soporte o resistencia
  String pricePosition(double currentPrice, List<SRLevel> levels) {
    for (final level in levels) {
      final dist = ((currentPrice - level.price) / level.price).abs();
      if (dist < 0.02) {
        return level.type == SRType.support
            ? 'En zona de soporte'
            : 'En zona de resistencia';
      }
    }
    return 'Entre niveles';
  }
}
