import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsItem {
  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
  final List<String> currencies;
  final int votes;
  final String sentiment; // positive | negative | neutral

  const NewsItem({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.currencies,
    required this.votes,
    required this.sentiment,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) {
    final votes = j['votes'] as Map<String, dynamic>? ?? {};
    final pos = (votes['positive'] as num?)?.toInt() ?? 0;
    final neg = (votes['negative'] as num?)?.toInt() ?? 0;
    String sentiment = 'neutral';
    if (pos > neg + 5) sentiment = 'positive';
    if (neg > pos + 5) sentiment = 'negative';

    final currencies = (j['currencies'] as List<dynamic>?)
            ?.map((c) => (c as Map<String, dynamic>)['code'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    return NewsItem(
      title: j['title'] as String? ?? '',
      url: j['url'] as String? ?? '',
      source: (j['source'] as Map<String, dynamic>?)?['title'] as String? ?? 'Crypto',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(
          ((j['published_at'] as num?)?.toInt() ?? 0) * 1000),
      currencies: currencies,
      votes: pos + neg,
      sentiment: sentiment,
    );
  }
}

class NewsService {
  static final NewsService _i = NewsService._();
  factory NewsService() => _i;
  NewsService._();

  static const _baseUrl = 'https://cryptopanic.com/api/v1';
  static const _key = 'free'; // CryptoPanic tiene endpoint sin auth para básico

  Future<List<NewsItem>> fetchNews({String? currency, int page = 1}) async {
    try {
      final params = {
        'auth_token': _key,
        'public': 'true',
        if (currency != null) 'currencies': currency,
        'page': '$page',
      };
      final uri = Uri.parse('$_baseUrl/posts/').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return _fallback();
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((j) => NewsItem.fromJson(j as Map<String, dynamic>))
          .where((n) => n.title.isNotEmpty)
          .toList();
    } catch (_) {
      return _fallback();
    }
  }

  List<NewsItem> _fallback() => [
        NewsItem(
          title: 'No se pudieron cargar las noticias. Revisá tu conexión.',
          url: '',
          source: '',
          publishedAt: DateTime.now(),
          currencies: [],
          votes: 0,
          sentiment: 'neutral',
        ),
      ];
}
