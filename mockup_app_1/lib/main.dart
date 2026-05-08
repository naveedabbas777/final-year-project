import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/market_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/my_listings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin/admin_console_shell.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/providers/auth_provider.dart' as app_auth;
import 'package:mockup_app/services/notification_service.dart';
import 'package:mockup_app/services/push_service.dart';
import 'package:mockup_app/services/alert_service.dart';
import 'package:mockup_app/services/api_client.dart';
import 'package:mockup_app/services/firebase_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mockup_app/providers/plant_disease_provider.dart';

// Top-level background handler required by `firebase_messaging`.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background FCM message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase before running the app. Uses default options from
  // `android/app/google-services.json` (Android) and the web config when on web.
  await Firebase.initializeApp();

  try {
    final config = await ApiClient().get('/api/config/public');
    final mapboxAccessToken =
        config is Map<String, dynamic>
            ? config['mapboxAccessToken'] as String? ?? ''
            : '';

    if (mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(mapboxAccessToken);
    } else {
      debugPrint('MAPBOX_ACCESS_TOKEN is not set; Mapbox features may fail.');
    }
  } catch (error) {
    debugPrint('Failed to load Mapbox token from backend: $error');
  }

  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();

  // Register background handler for FCM messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (iOS / Android 13+)
  await notificationService.requestNotificationPermissions();

  // Initialize PushService (handles token registration, channels, tap nav)
  await PushService.instance.init();

  // Print / log FCM token for debugging
  final fcmToken = await notificationService.getFcmToken();
  debugPrint('FCM Token: $fcmToken');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlantDiseaseProvider()),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider(create: (_) => AlertService()),
      ],
      child: const DigitalKissanApp(),
    ),
  );
}

class DigitalKissanApp extends StatelessWidget {
  const DigitalKissanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LanguageProvider>(context);
    return MaterialApp(
      title: 'Digital Kissan App',
      navigatorKey: navigatorKey,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('ur', '')],
      theme: AppTheme.light.copyWith(
        textTheme: GoogleFonts.notoSansTextTheme().copyWith(
          bodyLarge: GoogleFonts.notoSans(),
          bodyMedium: GoogleFonts.notoSans(),
          bodySmall: GoogleFonts.notoSans(),
          titleLarge: GoogleFonts.notoSans(),
          titleMedium: GoogleFonts.notoSans(),
          titleSmall: GoogleFonts.notoSans(),
        ),
      ),
      home: const AppRouter(),
      debugShowCheckedModeBanner: false,
      // Named routes for notification deep-link navigation
      routes: {
        '/offers': (_) => const OffersScreen(),
        '/orders': (_) => const OrdersScreen(),
        '/my-listings': (_) => const MyListingsScreen(),
        '/market': (_) => MarketScreen(),
        '/alerts': (_) => AlertsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  listingId: args['listingId'] ?? '',
                  toUid: args['toUid'] ?? '',
                ),
          );
        }
        return null;
      },
    );
  }
}

/// Reactive root router — rebuilds whenever [AuthProvider] notifies.
/// • Bootstrap pending  → SplashScreen
/// • Signed in          → RoleBasedHomeScreen  (role resolved inside)
/// • Signed out         → LoginScreenWrapper
///
/// This single widget handles ALL navigation transitions including sign-out;
/// no imperative Navigator calls are required anywhere in the auth flow.
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (_, auth, __) {
        // Auth state not yet resolved — keep showing splash
        if (!auth.isBootstrapComplete) {
          return const SplashScreen();
        }
        // Signed in → go to home (admin or farmer dashboard)
        if (auth.isSignedIn) {
          return const RoleBasedHomeScreen();
        }
        // Not signed in → go to login
        return const LoginScreenWrapper();
      },
    );
  }
}

class LoginScreenWrapper extends StatelessWidget {
  const LoginScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // onLogin is intentionally a no-op: once FirebaseAuth.signIn() completes,
    // AuthProvider.notifyListeners() fires and AppRouter rebuilds automatically,
    // showing RoleBasedHomeScreen without any imperative navigation needed.
    return LoginScreen(onLogin: () {});
  }
}

class RoleBasedHomeScreen extends StatefulWidget {
  const RoleBasedHomeScreen({super.key});

  @override
  State<RoleBasedHomeScreen> createState() => _RoleBasedHomeScreenState();
}

class _RoleBasedHomeScreenState extends State<RoleBasedHomeScreen> {
  late final Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _fetchRole();
  }

  Future<String> _fetchRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'farmer';
    final profile = await FirebaseService().getUserByUid(user.uid);
    final role = (profile?['role'] ?? '').toString().trim().toLowerCase();
    return role.isEmpty ? 'farmer' : role;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final role = snapshot.data ?? 'farmer';
        if (role == 'admin') {
          return const AdminConsoleShell();
        }
        return const MainNavigationShell();
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    DashboardScreen(),
    ForecastScreen(),
    AlertsScreen(),
    MarketScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
            tooltip: 'Home dashboard',
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: AppLocalizations.of(context)!.forecast,
            tooltip: 'Weather forecast',
          ),
          // Alerts tab with live unread badge
          Consumer<AlertService>(
            builder: (_, service, __) {
              final count = service.unreadCount;
              return NavigationDestination(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications),
                ),
                label: AppLocalizations.of(context)!.alerts,
                tooltip: count > 0 ? '$count unread alerts' : 'Weather alerts',
              );
            },
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: 'Market',
            tooltip: 'Marketplace',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
            tooltip: 'App settings',
          ),
        ],
      ),
    );
  }
}
