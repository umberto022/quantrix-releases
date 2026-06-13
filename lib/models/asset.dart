class Asset {
  final String id;
  final String symbol;
  final String name;
  final String type; // crypto, stock, forex
  final double price;
  final double change24h;
  final double changePercent24h;
  final double volume24h;
  final double marketCap;
  final String? imageUrl;
  final List<double> sparkline;

  Asset({
    required this.id,
    required this.symbol,
    required this.name,
    required this.type,
    required this.price,
    required this.change24h,
    required this.changePercent24h,
    required this.volume24h,
    required this.marketCap,
    this.imageUrl,
    this.sparkline = const [],
  });

  bool get isBullish => changePercent24h >= 0;

  factory Asset.fromCoinGecko(Map<String, dynamic> json) {
    final sparklineData = (json['sparkline_in_7d']?['price'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    return Asset(
      id: json['id'] ?? '',
      symbol: (json['symbol'] ?? '').toUpperCase(),
      name: json['name'] ?? '',
      type: 'crypto',
      price: (json['current_price'] as num?)?.toDouble() ?? 0,
      change24h: (json['price_change_24h'] as num?)?.toDouble() ?? 0,
      changePercent24h: (json['price_change_percentage_24h'] as num?)?.toDouble() ?? 0,
      volume24h: (json['total_volume'] as num?)?.toDouble() ?? 0,
      marketCap: (json['market_cap'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image'],
      sparkline: sparklineData,
    );
  }

  factory Asset.fromAlphaVantage(String symbol, Map<String, dynamic> json) {
    final quote = json['Global Quote'] ?? {};
    final price = double.tryParse(quote['05. price'] ?? '0') ?? 0;
    final change = double.tryParse(quote['09. change'] ?? '0') ?? 0;
    final changePct = double.tryParse(
            (quote['10. change percent'] ?? '0%').replaceAll('%', '')) ??
        0;
    return Asset(
      id: symbol.toLowerCase(),
      symbol: symbol,
      name: symbol,
      type: 'stock',
      price: price,
      change24h: change,
      changePercent24h: changePct,
      volume24h: double.tryParse(quote['06. volume'] ?? '0') ?? 0,
      marketCap: 0,
    );
  }
}
