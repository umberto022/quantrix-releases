import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/exchange_service.dart';
import '../theme/app_theme.dart';

// Exchanges disponibles
final _allExchanges = ['Binance', 'KuCoin', 'Bybit', 'OKX', 'Gate.io'];

// Cryptos disponibles para comparar
const _assets = [
  {'symbol': 'BTC', 'name': 'Bitcoin'},
  {'symbol': 'ETH', 'name': 'Ethereum'},
  {'symbol': 'BNB', 'name': 'BNB'},
  {'symbol': 'SOL', 'name': 'Solana'},
  {'symbol': 'XRP', 'name': 'XRP'},
  {'symbol': 'DOGE', 'name': 'Dogecoin'},
  {'symbol': 'ADA', 'name': 'Cardano'},
  {'symbol': 'AVAX', 'name': 'Avalanche'},
  {'symbol': 'DOT', 'name': 'Polkadot'},
  {'symbol': 'MATIC', 'name': 'Polygon'},
  {'symbol': 'LTC', 'name': 'Litecoin'},
  {'symbol': 'LINK', 'name': 'Chainlink'},
];

final _exchangePricesProvider = FutureProvider.family<List<ExchangePrice>, String>(
  (ref, symbol) => ExchangeService().getPrices(symbol),
);

class ExchangesScreen extends ConsumerStatefulWidget {
  const ExchangesScreen({super.key});

  @override
  ConsumerState<ExchangesScreen> createState() => _ExchangesScreenState();
}

class _ExchangesScreenState extends ConsumerState<ExchangesScreen>
    with SingleTickerProviderStateMixin {
  String _selectedSymbol = 'BTC';
  Set<String> _myExchanges = {'Binance', 'KuCoin', 'Bybit'};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrefs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('my_exchanges');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _myExchanges = saved.toSet());
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_exchanges', _myExchanges.toList());
  }

  void _toggleExchange(String name) {
    setState(() {
      if (_myExchanges.contains(name)) {
        if (_myExchanges.length > 1) _myExchanges.remove(name);
      } else {
        _myExchanges.add(name);
      }
    });
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar Exchanges'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Comparar Precios'),
            Tab(text: 'Mis Plataformas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComparadorTab(
            selectedSymbol: _selectedSymbol,
            myExchanges: _myExchanges,
            onSymbolChanged: (s) => setState(() => _selectedSymbol = s),
            ref: ref,
          ),
          _MisPlataformasTab(
            myExchanges: _myExchanges,
            onToggle: _toggleExchange,
          ),
        ],
      ),
    );
  }
}

class _ComparadorTab extends StatelessWidget {
  final String selectedSymbol;
  final Set<String> myExchanges;
  final ValueChanged<String> onSymbolChanged;
  final WidgetRef ref;

  const _ComparadorTab({
    required this.selectedSymbol,
    required this.myExchanges,
    required this.onSymbolChanged,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(_exchangePricesProvider(selectedSymbol));

    return Column(
      children: [
        // Selector de cripto
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _assets.length,
            itemBuilder: (ctx, i) {
              final a = _assets[i];
              final selected = a['symbol'] == selectedSymbol;
              return GestureDetector(
                onTap: () {
                  onSymbolChanged(a['symbol']!);
                  ref.invalidate(_exchangePricesProvider(a['symbol']!));
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.cardBorder,
                    ),
                  ),
                  child: Text(
                    a['symbol']!,
                    style: TextStyle(
                      color: selected ? Colors.black : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: pricesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
                  const SizedBox(height: 12),
                  const Text('Sin conexión o error al cargar precios',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    onPressed: () => ref.invalidate(_exchangePricesProvider(selectedSymbol)),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
            data: (prices) {
              final filtered = prices.where((p) => myExchanges.contains(p.exchange)).toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Sin datos para tus exchanges activos',
                      style: TextStyle(color: AppTheme.textSecondary)),
                );
              }

              // Ordenar por precio de compra
              filtered.sort((a, b) => a.buyPrice.compareTo(b.buyPrice));
              final best = filtered.first;
              final worst = filtered.last;
              final diffPct = worst.buyPrice > 0
                  ? ((worst.buyPrice - best.buyPrice) / worst.buyPrice) * 100
                  : 0.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recomendación
                    _RecommendationCard(
                      symbol: selectedSymbol,
                      best: best,
                      diffPct: diffPct,
                    ),
                    const SizedBox(height: 16),

                    // Tabla de precios
                    const Text('Precios por exchange',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    ...filtered.map((p) => _ExchangePriceCard(
                          price: p,
                          isBest: p.exchange == best.exchange,
                          bestPrice: best.buyPrice,
                        )),

                    const SizedBox(height: 16),

                    // Info spread
                    if (diffPct > 0.1)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Diferencia entre exchanges: ${diffPct.toStringAsFixed(2)}%  '
                                '(${_formatPrice(worst.buyPrice - best.buyPrice, selectedSymbol)} USDT de ahorro comprando en ${best.exchange})',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),
                    const Text(
                      '* Precios en tiempo real (par USDT). Solo para análisis de mercado.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price, String symbol) {
    if (symbol == 'BTC' || price > 100) {
      return NumberFormat('#,##0.00').format(price);
    }
    return NumberFormat('#,##0.0000').format(price);
  }
}

class _RecommendationCard extends StatelessWidget {
  final String symbol;
  final ExchangePrice best;
  final double diffPct;

  const _RecommendationCard({
    required this.symbol,
    required this.best,
    required this.diffPct,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = symbol == 'BTC' || best.buyPrice > 100
        ? NumberFormat('#,##0.00')
        : NumberFormat('#,##0.0000');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.bullish.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.bullish.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.recommend, color: AppTheme.bullish, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mejor precio para comprar $symbol',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                best.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    best.exchange,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  Text(
                    '\$${fmt.format(best.buyPrice)} USDT',
                    style: const TextStyle(
                        color: AppTheme.bullish,
                        fontWeight: FontWeight.w600,
                        fontSize: 16),
                  ),
                ],
              ),
              const Spacer(),
              if (diffPct > 0.05)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.bullish.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${diffPct.toStringAsFixed(2)}%\nvs más caro',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.bullish,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExchangePriceCard extends StatelessWidget {
  final ExchangePrice price;
  final bool isBest;
  final double bestPrice;

  const _ExchangePriceCard({
    required this.price,
    required this.isBest,
    required this.bestPrice,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = price.buyPrice > 100
        ? NumberFormat('#,##0.00')
        : NumberFormat('#,##0.0000');

    final overpricePct = bestPrice > 0
        ? ((price.buyPrice - bestPrice) / bestPrice) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isBest
            ? AppTheme.bullish.withValues(alpha: 0.05)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest
              ? AppTheme.bullish.withValues(alpha: 0.4)
              : AppTheme.cardBorder,
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(price.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      price.exchange,
                      style: TextStyle(
                        color: isBest
                            ? AppTheme.bullish
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.bullish,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('MEJOR',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Spread: ${price.spreadPct.toStringAsFixed(3)}%',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${fmt.format(price.buyPrice)}',
                style: TextStyle(
                  color:
                      isBest ? AppTheme.bullish : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (!isBest && overpricePct > 0.01)
                Text(
                  '+${overpricePct.toStringAsFixed(2)}% más caro',
                  style: const TextStyle(
                      color: AppTheme.bearish, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MisPlataformasTab extends StatelessWidget {
  final Set<String> myExchanges;
  final ValueChanged<String> onToggle;

  const _MisPlataformasTab({
    required this.myExchanges,
    required this.onToggle,
  });

  static const _exchangeInfo = {
    'Binance': {'emoji': '🟡', 'desc': 'Mayor volumen del mundo'},
    'KuCoin': {'emoji': '🟢', 'desc': 'Gran variedad de altcoins'},
    'Bybit': {'emoji': '🟠', 'desc': 'Fuerte en derivados y spot'},
    'OKX': {'emoji': '🔵', 'desc': 'Liquider alta, buenas comisiones'},
    'Gate.io': {'emoji': '⚫', 'desc': 'Criptos emergentes y nuevos proyectos'},
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Seleccioná las plataformas donde tenés cuenta para comparar precios entre ellas.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._allExchanges.map((name) {
          final info = _exchangeInfo[name]!;
          final active = myExchanges.contains(name);
          return GestureDetector(
            onTap: () => onToggle(name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? AppTheme.primary : AppTheme.cardBorder,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(info['emoji']!, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: active
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          info['desc']!,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? AppTheme.primary : AppTheme.cardBorder,
                        width: 2,
                      ),
                    ),
                    child: active
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text(
          'Los precios se obtienen de las APIs públicas de cada exchange. '
          'No se almacenan credenciales ni datos de cuenta.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
