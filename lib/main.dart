import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'models/portfolio_entry.dart';
import 'models/alert_rule.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/connection_service.dart';
import 'services/fcm_service.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/signals_screen.dart';
import 'screens/screener_screen.dart';
import 'screens/news_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación fija vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Inicializar Hive con adaptadores registrados
  try {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PortfolioEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AlertRuleAdapter());
    }
    await Hive.openBox<PortfolioEntry>('portfolio');
    await Hive.openBox<AlertRule>('alert_rules');
  } catch (_) {}

  // Inicializar Firebase de forma segura con timeout
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (_) {}

  // Inicializar servicio de conexión
  try {
    ConnectionService().init();
  } catch (_) {}

  runApp(const ProviderScope(child: QuantrixApp()));
}

class QuantrixApp extends ConsumerWidget {
  const QuantrixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Quantrix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}

// Enruta automáticamente según estado de autenticación
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final auth = ref.watch(authProvider);
      return switch (auth.status) {
        AuthStatus.loading => const SplashScreen(),
        AuthStatus.authenticated => const MainShell(),
        AuthStatus.unauthenticated => const LoginScreen(),
      };
    } catch (_) {
      return const LoginScreen();
    }
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    DashboardScreen(),
    SignalsScreen(),
    ScreenerScreen(),
    NewsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // FCM — solo si Firebase está disponible
      try {
        await FcmService().init();
      } catch (_) {}
      // Verificar actualizaciones
      try {
        final update = await UpdateService().checkForUpdate();
        if (mounted && update != null) {
          await UpdateDialog.showIfNeeded(context, update);
        }
      } catch (_) {}
    });
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Mercado'),
          BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Señales'),
          BottomNavigationBarItem(icon: Icon(Icons.filter_list), label: 'Screener'),
          BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), label: 'Noticias'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
