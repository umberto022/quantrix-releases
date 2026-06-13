import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class HomeWidgetService {
  static final HomeWidgetService _i = HomeWidgetService._();
  factory HomeWidgetService() => _i;
  HomeWidgetService._();

  static const _appGroupId = 'com.quantrix.quantrix_app';
  static const _widgetName = 'QuantrixWidgetProvider';

  Future<void> updatePrices({
    required double btcPrice,
    required double btcChange,
    required double ethPrice,
    required double ethChange,
    required double fearGreed,
  }) async {
    final fmt = NumberFormat.compactCurrency(symbol: '\$');
    final now = DateFormat('HH:mm').format(DateTime.now());

    String fgiLabel;
    if (fearGreed < 20) fgiLabel = 'Miedo ext.';
    else if (fearGreed < 40) fgiLabel = 'Miedo';
    else if (fearGreed < 60) fgiLabel = 'Neutral';
    else if (fearGreed < 80) fgiLabel = 'Codicia';
    else fgiLabel = 'Codicia ext.';

    await HomeWidget.saveWidgetData('btc_price', fmt.format(btcPrice));
    await HomeWidget.saveWidgetData('btc_change',
        '${btcChange >= 0 ? '+' : ''}${btcChange.toStringAsFixed(2)}%');
    await HomeWidget.saveWidgetData('eth_price', fmt.format(ethPrice));
    await HomeWidget.saveWidgetData('eth_change',
        '${ethChange >= 0 ? '+' : ''}${ethChange.toStringAsFixed(2)}%');
    await HomeWidget.saveWidgetData('fgi', fearGreed.toInt().toString());
    await HomeWidget.saveWidgetData('fgi_label', fgiLabel);
    await HomeWidget.saveWidgetData('updated', now);

    await HomeWidget.updateWidget(
      androidName: _widgetName,
      iOSName: _widgetName,
      qualifiedAndroidName: '$_appGroupId.$_widgetName',
    );
  }
}
