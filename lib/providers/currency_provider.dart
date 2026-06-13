import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

const List<Currency> supportedCurrencies = [
  Currency(code: 'USD', symbol: '\$',   name: 'Dólar Estadounidense', flag: '🇺🇸'),
  Currency(code: 'ARS', symbol: '\$',   name: 'Peso Argentino',       flag: '🇦🇷'),
  Currency(code: 'EUR', symbol: '€',    name: 'Euro',                  flag: '🇪🇺'),
  Currency(code: 'BRL', symbol: 'R\$',  name: 'Real Brasileño',        flag: '🇧🇷'),
  Currency(code: 'MXN', symbol: '\$',   name: 'Peso Mexicano',         flag: '🇲🇽'),
  Currency(code: 'CLP', symbol: '\$',   name: 'Peso Chileno',          flag: '🇨🇱'),
  Currency(code: 'COP', symbol: '\$',   name: 'Peso Colombiano',       flag: '🇨🇴'),
  Currency(code: 'DOP', symbol: 'RD\$', name: 'Peso Dominicano',       flag: '🇩🇴'),
  Currency(code: 'GBP', symbol: '£',    name: 'Libra Esterlina',       flag: '🇬🇧'),
  Currency(code: 'JPY', symbol: '¥',    name: 'Yen Japonés',           flag: '🇯🇵'),
  Currency(code: 'CAD', symbol: 'CA\$', name: 'Dólar Canadiense',      flag: '🇨🇦'),
  Currency(code: 'CHF', symbol: 'Fr',   name: 'Franco Suizo',          flag: '🇨🇭'),
  Currency(code: 'AUD', symbol: 'A\$',  name: 'Dólar Australiano',     flag: '🇦🇺'),
  Currency(code: 'VES', symbol: 'Bs',   name: 'Bolívar Venezolano',    flag: '🇻🇪'),
  Currency(code: 'PEN', symbol: 'S/.',  name: 'Sol Peruano',           flag: '🇵🇪'),
  Currency(code: 'UYU', symbol: '\$U',  name: 'Peso Uruguayo',         flag: '🇺🇾'),
];

// Tasa de cambio USD → moneda seleccionada
final exchangeRateProvider = FutureProvider.family<double, String>((ref, currencyCode) async {
  if (currencyCode == 'USD') return 1.0;

  // Caso especial Argentina — intenta obtener dólar blue
  if (currencyCode == 'ARS') {
    try {
      final res = await Dio().get('https://dolarapi.com/v1/dolares/blue');
      final blue = (res.data['venta'] as num?)?.toDouble();
      if (blue != null && blue > 0) return blue;
    } catch (_) {}
  }

  // Frankfurter para el resto
  try {
    final res = await Dio().get(
      'https://api.frankfurter.app/latest',
      queryParameters: {'from': 'USD', 'to': currencyCode},
    );
    return (res.data['rates'][currencyCode] as num).toDouble();
  } catch (_) {
    return 1.0;
  }
});

// Moneda activa del usuario
final selectedCurrencyProvider = StateNotifierProvider<CurrencyNotifier, Currency>((ref) {
  return CurrencyNotifier();
});

class CurrencyNotifier extends StateNotifier<Currency> {
  CurrencyNotifier() : super(supportedCurrencies.first) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('currency') ?? 'USD';
    final currency = supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );
    state = currency;
  }

  Future<void> select(Currency currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency.code);
  }
}

// Helper: convierte precio USD a moneda local
class CurrencyConverter {
  final double rate;
  final Currency currency;

  const CurrencyConverter({required this.rate, required this.currency});

  double convert(double usdPrice) => usdPrice * rate;

  String format(double usdPrice) {
    final value = convert(usdPrice);
    if (value >= 1000000) {
      return '${currency.symbol}${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      return '${currency.symbol}${(value / 1000).toStringAsFixed(2)}K';
    } else if (value < 1) {
      return '${currency.symbol}${value.toStringAsFixed(6)}';
    }
    return '${currency.symbol}${value.toStringAsFixed(2)}';
  }
}

final currencyConverterProvider = FutureProvider<CurrencyConverter>((ref) async {
  final currency = ref.watch(selectedCurrencyProvider);
  final rate = await ref.watch(exchangeRateProvider(currency.code).future);
  return CurrencyConverter(rate: rate, currency: currency);
});
