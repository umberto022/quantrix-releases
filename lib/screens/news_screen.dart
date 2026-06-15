import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/news_service.dart';
import '../theme/app_theme.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late Future<List<NewsItem>> _future;
  String? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _future = NewsService().fetchNews(currency: _filter);
  }

  void _applyFilter(String? currency) {
    setState(() {
      _filter = currency;
      _future = NewsService().fetchNews(currency: currency);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Noticias cripto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () => setState(() {
              _future = NewsService().fetchNews(currency: _filter);
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros rápidos
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _FilterChip(label: 'Todas', selected: _filter == null, onTap: () => _applyFilter(null)),
                _FilterChip(label: 'BTC', selected: _filter == 'BTC', onTap: () => _applyFilter('BTC')),
                _FilterChip(label: 'ETH', selected: _filter == 'ETH', onTap: () => _applyFilter('ETH')),
                _FilterChip(label: 'SOL', selected: _filter == 'SOL', onTap: () => _applyFilter('SOL')),
                _FilterChip(label: 'XRP', selected: _filter == 'XRP', onTap: () => _applyFilter('XRP')),
                _FilterChip(label: 'BNB', selected: _filter == 'BNB', onTap: () => _applyFilter('BNB')),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<NewsItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                if (snap.hasError || snap.data == null) {
                  return const Center(
                    child: Text('Error cargando noticias',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  );
                }
                final items = snap.data!;
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    final fresh = await NewsService().fetchNews(currency: _filter);
                    if (mounted) setState(() => _future = Future.value(fresh));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _NewsCard(item: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppTheme.primary : AppTheme.cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  Color get _sentimentColor {
    if (item.sentiment == 'positive') return AppTheme.bullish;
    if (item.sentiment == 'negative') return AppTheme.bearish;
    return AppTheme.textSecondary;
  }

  IconData get _sentimentIcon {
    if (item.sentiment == 'positive') return Icons.trending_up;
    if (item.sentiment == 'negative') return Icons.trending_down;
    return Icons.trending_flat;
  }

  String get _sentimentLabel {
    if (item.sentiment == 'positive') return 'Positivo';
    if (item.sentiment == 'negative') return 'Negativo';
    return 'Neutral';
  }

  @override
  Widget build(BuildContext context) {
    final color = _sentimentColor;
    final timeAgo = _timeAgo(item.publishedAt);

    return GestureDetector(
      onTap: () async {
        if (item.url.isEmpty) return;
        final uri = Uri.tryParse(item.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.sentiment != 'neutral'
                ? color.withValues(alpha: 0.3)
                : AppTheme.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sentimentIcon, color: color, size: 12),
                      const SizedBox(width: 4),
                      Text(_sentimentLabel,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                if (item.currencies.isNotEmpty)
                  ...item.currencies.take(3).map((c) => Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(c,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                      )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(item.source,
                    style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Text('· $timeAgo',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const Spacer(),
                if (item.url.isNotEmpty)
                  const Icon(Icons.open_in_new, color: AppTheme.textSecondary, size: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return DateFormat('dd MMM').format(dt);
  }
}
