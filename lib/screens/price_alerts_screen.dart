import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/price_alert_provider.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';

class PriceAlertsScreen extends ConsumerStatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  ConsumerState<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends ConsumerState<PriceAlertsScreen> {
  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(priceAlertProvider);
    final active = alerts.where((a) => !a.triggered).toList();
    final triggered = alerts.where((a) => a.triggered).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de precio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: alerts.isEmpty
          ? _EmptyView(onAdd: () => _showAddDialog(context))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  const _SectionLabel('ACTIVAS'),
                  const SizedBox(height: 8),
                  ...active.map((a) => _AlertTile(
                        alert: a,
                        onDelete: () => ref.read(priceAlertProvider.notifier).remove(a.id),
                      )),
                  const SizedBox(height: 16),
                ],
                if (triggered.isNotEmpty) ...[
                  const _SectionLabel('DISPARADAS'),
                  const SizedBox(height: 8),
                  ...triggered.map((a) => _AlertTile(
                        alert: a,
                        onDelete: () => ref.read(priceAlertProvider.notifier).remove(a.id),
                      )),
                ],
              ],
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final cryptosAsync = ref.read(topCryptosProvider);
    String assetId = 'bitcoin';
    String symbol = 'BTC';
    double targetPrice = 0;
    AlertCondition condition = AlertCondition.above;
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva alerta de precio',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              cryptosAsync.when(
                data: (cryptos) => DropdownButtonFormField<String>(
                  dropdownColor: AppTheme.surfaceLight,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _deco('Activo'),
                  value: assetId,
                  items: cryptos.take(30).map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.symbol} — ${a.name}',
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    assetId = v;
                    final a = cryptos.firstWhere((c) => c.id == v);
                    symbol = a.symbol;
                    setS(() {});
                  },
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => condition = AlertCondition.above),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: condition == AlertCondition.above
                            ? AppTheme.bullish.withOpacity(0.15)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: condition == AlertCondition.above ? AppTheme.bullish : AppTheme.cardBorder,
                        ),
                      ),
                      child: const Center(
                        child: Text('Sube a >', style: TextStyle(color: AppTheme.bullish, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => condition = AlertCondition.below),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: condition == AlertCondition.below
                            ? AppTheme.bearish.withOpacity(0.15)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: condition == AlertCondition.below ? AppTheme.bearish : AppTheme.cardBorder,
                        ),
                      ),
                      child: const Center(
                        child: Text('Baja a <', style: TextStyle(color: AppTheme.bearish, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _deco('Precio objetivo (USD)'),
                onChanged: (v) => targetPrice = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (targetPrice <= 0) return;
                    ref.read(priceAlertProvider.notifier).add(PriceAlert(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      assetId: assetId,
                      symbol: symbol,
                      targetPrice: targetPrice,
                      condition: condition,
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Crear alerta', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.cardBorder)),
      );
}

class _AlertTile extends StatelessWidget {
  final PriceAlert alert;
  final VoidCallback onDelete;
  const _AlertTile({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final isAbove = alert.condition == AlertCondition.above;
    final color = alert.triggered
        ? AppTheme.textSecondary
        : (isAbove ? AppTheme.bullish : AppTheme.bearish);
    final condLabel = isAbove ? 'Sube a' : 'Baja a';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: alert.triggered ? AppTheme.cardBorder : color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              alert.triggered ? Icons.check : (isAbove ? Icons.arrow_upward : Icons.arrow_downward),
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.symbol,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                Text('$condLabel ${fmt.format(alert.targetPrice)}',
                    style: TextStyle(color: color, fontSize: 12)),
                if (alert.triggered)
                  const Text('Disparada', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 1.2));
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, color: AppTheme.textSecondary, size: 64),
            const SizedBox(height: 16),
            const Text('Sin alertas activas',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Creá una alerta para recibir notificaciones',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Nueva alerta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}
