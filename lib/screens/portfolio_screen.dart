import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/portfolio_provider.dart';
import '../providers/market_provider.dart';
import '../models/portfolio_entry.dart';
import '../theme/app_theme.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  final fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  final fmtCompact = NumberFormat.compactCurrency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(portfolioProvider);
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final cryptosAsync = ref.watch(topCryptosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: entries.isEmpty
          ? _EmptyPortfolio(onAdd: () => _showAddDialog(context))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  summaryAsync.when(
                    data: (summary) => _SummaryCard(summary: summary, fmt: fmt),
                    loading: () => const _SummaryCardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),

                  // Donut chart
                  if (entries.length > 1) ...[
                    const Text('Distribución',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: entries.asMap().entries.map((e) {
                            final colors = [
                              AppTheme.primary,
                              AppTheme.bearish,
                              AppTheme.warning,
                              const Color(0xFF7B68EE),
                              const Color(0xFF20B2AA),
                            ];
                            return PieChartSectionData(
                              color: colors[e.key % colors.length],
                              value: e.value.invested,
                              title: e.value.symbol,
                              radius: 70,
                              titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            );
                          }).toList(),
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Positions list
                  const Text('Posiciones',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...entries.map((entry) => cryptosAsync.when(
                        data: (cryptos) {
                          final asset = cryptos.cast<dynamic>().firstWhere(
                                (a) => a.id == entry.assetId,
                                orElse: () => null,
                              );
                          final currentPrice = asset?.price ?? entry.buyPrice;
                          return _PositionCard(
                            entry: entry,
                            currentPrice: currentPrice,
                            fmt: fmt,
                            fmtCompact: fmtCompact,
                            onDelete: () => ref
                                .read(portfolioProvider.notifier)
                                .remove(entry.id),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      )),
                ],
              ),
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String assetId = 'bitcoin';
    String symbol = 'BTC';
    String name = 'Bitcoin';
    double quantity = 0;
    double buyPrice = 0;

    final cryptosAsync = ref.read(topCryptosProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Agregar posición',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Asset selector
              cryptosAsync.when(
                data: (cryptos) => DropdownButtonFormField<String>(
                  dropdownColor: AppTheme.surfaceLight,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _inputDeco('Activo'),
                  initialValue: assetId,
                  items: cryptos
                      .take(20)
                      .map((a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.symbol} — ${a.name}',
                                style: const TextStyle(color: AppTheme.textPrimary)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    assetId = val;
                    final a = cryptos.firstWhere((c) => c.id == val);
                    symbol = a.symbol;
                    name = a.name;
                    buyPrice = a.price;
                  },
                ),
                loading: () => const CircularProgressIndicator(color: AppTheme.primary),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDeco('Cantidad'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Ingresa una cantidad válida' : null,
                onChanged: (v) => quantity = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 12),
              TextFormField(
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: _inputDeco('Precio de compra (USD)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Ingresa un precio válido' : null,
                onChanged: (v) => buyPrice = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    ref.read(portfolioProvider.notifier).add(PortfolioEntry(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          assetId: assetId,
                          symbol: symbol,
                          name: name,
                          type: 'crypto',
                          quantity: quantity,
                          buyPrice: buyPrice,
                          buyDate: DateTime.now(),
                        ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
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

class _SummaryCard extends StatelessWidget {
  final Map<String, double> summary;
  final NumberFormat fmt;
  const _SummaryCard({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pnl = summary['pnl'] ?? 0;
    final pnlPct = summary['pnlPercent'] ?? 0;
    final isPositive = pnl >= 0;
    final color = isPositive ? AppTheme.bullish : AppTheme.bearish;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.surface, AppTheme.surfaceLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Valor total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(fmt.format(summary['current'] ?? 0),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16),
              Text(
                '${fmt.format(pnl.abs())} (${pnlPct.toStringAsFixed(2)}%)',
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem('Invertido', fmt.format(summary['invested'] ?? 0)),
              _StatItem('P&L', fmt.format(pnl), color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.label, this.value, {this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );
}

class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 140,
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      );
}

class _PositionCard extends StatelessWidget {
  final PortfolioEntry entry;
  final double currentPrice;
  final NumberFormat fmt;
  final NumberFormat fmtCompact;
  final VoidCallback onDelete;

  const _PositionCard({
    required this.entry,
    required this.currentPrice,
    required this.fmt,
    required this.fmtCompact,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pnl = entry.pnl(currentPrice);
    final pnlPct = entry.pnlPercent(currentPrice);
    final isPos = pnl >= 0;
    final color = isPos ? AppTheme.bullish : AppTheme.bearish;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.surfaceLight,
            child: Text(entry.symbol.substring(0, 1),
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.symbol,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                Text('${entry.quantity} × ${fmt.format(entry.buyPrice)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(entry.currentValue(currentPrice)),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              Text(
                '${isPos ? '+' : ''}${fmt.format(pnl)} (${pnlPct.toStringAsFixed(2)}%)',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
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

class _EmptyPortfolio extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPortfolio({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pie_chart_outline, color: AppTheme.textSecondary, size: 64),
            const SizedBox(height: 16),
            const Text('Tu portfolio está vacío',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Agregá tus primeras posiciones',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: onAdd,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Agregar posición',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}
