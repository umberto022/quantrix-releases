import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'admin_screen.dart';
import 'exchanges_screen.dart';
import 'portfolio_screen.dart';
import 'price_alerts_screen.dart';
import 'ai_chat_screen.dart';

// Emails con acceso de admin
const _adminEmails = ['pedromateo.desarrollo@gmail.com'];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCurrencyProvider);
    final converterAsync = ref.watch(currencyConverterProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isAdmin = _adminEmails.contains(user?.email ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Perfil
          if (user != null) ...[
            const _SectionHeader('PERFIL'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(user.email,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAdmin ? 'ADMIN' : user.plan.toUpperCase(),
                      style: TextStyle(
                        color: isAdmin ? AppTheme.warning : AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    title: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.textPrimary)),
                    content: const Text('¿Querés cerrar tu sesión?', style: TextStyle(color: AppTheme.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.bearish))),
                    ],
                  ),
                );
                if (confirm == true) ref.read(authProvider.notifier).logout();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bearish.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.bearish.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: AppTheme.bearish, size: 18),
                    SizedBox(width: 8),
                    Text('Cerrar sesión', style: TextStyle(color: AppTheme.bearish, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Funciones
          const _SectionHeader('FUNCIONES'),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Portafolio',
            subtitle: 'Rastreá tus posiciones y P&L en tiempo real',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PortfolioScreen())),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.notifications_active_outlined,
            label: 'Alertas de precio',
            subtitle: 'Notificaciones cuando el precio llegue a tu objetivo',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceAlertsScreen())),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.compare_arrows,
            label: 'Comparar Exchanges',
            subtitle: 'Precios en Binance, KuCoin, Bybit, OKX',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExchangesScreen())),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.auto_awesome_outlined,
            label: 'Chat IA',
            subtitle: 'Preguntá sobre mercados, señales e indicadores',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            _NavTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Panel de administrador',
              subtitle: 'Usuarios, estadísticas y notificaciones masivas',
              color: AppTheme.warning,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
          ],
          const SizedBox(height: 24),

          // Apariencia
          const _SectionHeader('APARIENCIA'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tema', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(isDark ? 'Oscuro' : 'Claro', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Moneda
          const _SectionHeader('MONEDA DE VISUALIZACIÃ“N'),
          const SizedBox(height: 8),
          converterAsync.when(
            data: (conv) => conv.currency.code == 'USD'
                ? const SizedBox.shrink()
                : Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tasa actual: 1 USD = ${conv.rate.toStringAsFixed(conv.rate > 100 ? 0 : 4)} ${conv.currency.code}'
                            '${conv.currency.code == 'ARS' ? ' (dólar blue)' : ''}',
                            style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          ...supportedCurrencies.map((currency) => _CurrencyTile(
                currency: currency,
                isSelected: selected.code == currency.code,
                onTap: () => ref.read(selectedCurrencyProvider.notifier).select(currency),
              )),

          const SizedBox(height: 24),
          const _SectionHeader('SOBRE QUANTRIX'),
          const SizedBox(height: 8),
          const _InfoTile('Versión', '1.2.2'),
          const _InfoTile('Datos crypto', 'CoinGecko API'),
          const _InfoTile('Datos acciones', 'Alpha Vantage'),
          const _InfoTile('Tipo de cambio', 'Frankfurter + DolarAPI'),
          const _InfoTile('Indicadores', 'RSI · MACD · SMA · Fear&Greed'),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(subtitle,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18),
            ],
          ),
        ),
      );
}

class _CurrencyTile extends StatelessWidget {
  final Currency currency;
  final bool isSelected;
  final VoidCallback onTap;
  const _CurrencyTile({required this.currency, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(currency.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currency.code,
                        style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(currency.name, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(currency.symbol,
                  style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
              ],
            ],
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2));
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            Text(value,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}
