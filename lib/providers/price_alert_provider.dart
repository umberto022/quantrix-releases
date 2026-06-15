import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum AlertCondition { above, below }

class PriceAlert {
  final String id;
  final String assetId;
  final String symbol;
  final double targetPrice;
  final AlertCondition condition;
  final bool triggered;

  const PriceAlert({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.targetPrice,
    required this.condition,
    this.triggered = false,
  });

  PriceAlert copyWith({bool? triggered}) => PriceAlert(
        id: id,
        assetId: assetId,
        symbol: symbol,
        targetPrice: targetPrice,
        condition: condition,
        triggered: triggered ?? this.triggered,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'symbol': symbol,
        'targetPrice': targetPrice,
        'condition': condition.index,
        'triggered': triggered,
      };

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
        id: j['id'],
        assetId: j['assetId'],
        symbol: j['symbol'],
        targetPrice: (j['targetPrice'] as num).toDouble(),
        condition: AlertCondition.values[j['condition'] as int],
        triggered: j['triggered'] as bool? ?? false,
      );

  String get conditionLabel => condition == AlertCondition.above ? '>' : '<';
}

final priceAlertProvider =
    StateNotifierProvider<PriceAlertNotifier, List<PriceAlert>>((ref) {
  return PriceAlertNotifier();
});

class PriceAlertNotifier extends StateNotifier<List<PriceAlert>> {
  static const _key = 'price_alerts_v2';
  final _notif = FlutterLocalNotificationsPlugin();

  PriceAlertNotifier() : super([]) {
    _load();
    _initNotif();
  }

  Future<void> _initNotif() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _notif.initialize(const InitializationSettings(android: androidInit));
    } catch (_) {}
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw
        .map((s) => PriceAlert.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, state.map((a) => jsonEncode(a.toJson())).toList());
  }

  Future<void> add(PriceAlert alert) async {
    state = [...state, alert];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _save();
  }

  /// Llamado desde MarketProvider al actualizar precios
  Future<void> checkPrices(Map<String, double> prices) async {
    bool changed = false;
    final updated = state.map((alert) {
      if (alert.triggered) return alert;
      final price = prices[alert.assetId];
      if (price == null) return alert;
      final fire = alert.condition == AlertCondition.above
          ? price >= alert.targetPrice
          : price <= alert.targetPrice;
      if (!fire) return alert;
      _fireNotification(alert, price);
      changed = true;
      return alert.copyWith(triggered: true);
    }).toList();

    if (changed) {
      state = updated;
      await _save();
    }
  }

  void _fireNotification(PriceAlert alert, double price) {
    _notif.show(
      alert.id.hashCode,
      '${alert.symbol} ${alert.conditionLabel} \$${alert.targetPrice.toStringAsFixed(2)}',
      'Precio actual: \$${price.toStringAsFixed(2)}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quantrix_price_alerts',
          'Alertas de Precio',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
