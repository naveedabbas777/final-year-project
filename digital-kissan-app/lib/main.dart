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
import 'screens/assistant_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/my_listings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin/admin_console_shell.dart';
import 'screens/profile_screen.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/providers/auth_provider.dart' as app_auth;
import 'package:mockup_app/services/notification_service.dart';
import 'package:mockup_app/services/push_service.dart';
import 'package:mockup_app/services/alert_service.dart';
import 'package:mockup_app/services/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mockup_app/providers/plant_disease_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Initialize PushService (handles token registration, channels, tap nav)
  await PushService.instance.init();

  // Print / log FCM token for debugging
  final fcmToken = await notificationService.getFcmToken();
  debugPrint('FCM Token: $fcmToken');

  final prefs = await SharedPreferences.getInstance();
  final savedLanguageCode = prefs.getString(LanguageProvider.localeStorageKey);
  final initialLocale = LanguageProvider.resolveLocale(savedLanguageCode);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLocale: initialLocale),
        ),
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
        '/assistant': (_) => const AssistantScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final args = settings.arguments as Map<String, dynamic>? ?? {};
          return MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  listingId: args['listingId'] ?? '',
                  toUid: args['toUid'] as String?,
                  productName: args['productName'] as String?,
                  productImageUrl: args['productImageUrl'] as String?,
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
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  static const String _kNotificationsEnabled = 'notifications_enabled';
  static const Duration _minimumSplashDuration = Duration(milliseconds: 2000);
  bool _notificationPromptShown = false;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minimumSplashDuration, () {
      if (!mounted) return;
      setState(() => _minimumSplashElapsed = true);
    });
  }

  Future<void> _maybeShowNotificationReminder({
    required bool isBootstrapComplete,
    required bool isSignedIn,
  }) async {
    if (!isBootstrapComplete || !isSignedIn || _notificationPromptShown) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final localPreference = prefs.getBool(_kNotificationsEnabled) ?? true;
    final systemStatus = await Permission.notification.status;
    final notificationsEnabled = localPreference && systemStatus.isGranted;

    if (notificationsEnabled || !mounted) return;

    _notificationPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Turn on notifications'),
              content: const Text(
                'Enable notifications to receive real-time weather updates, offer alerts, and new messages.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
      );

      if (shouldOpenSettings == true && mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (_, auth, __) {
        final readyForMainFlow =
            auth.isBootstrapComplete && _minimumSplashElapsed;

        _maybeShowNotificationReminder(
          isBootstrapComplete: readyForMainFlow,
          isSignedIn: auth.isSignedIn,
        );

        // Keep splash visible until auth bootstrap finishes and minimum
        // display time has elapsed, so transitions feel intentional.
        if (!readyForMainFlow) {
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
  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isRoleResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAdmin) {
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
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<app_auth.AuthProvider>(context);
    final Widget profileTab = auth.isAdmin ? const AdminProfileScreen() : const ProfileScreen();
    final List<Widget> _screens = [
      DashboardScreen(),
      ForecastScreen(),
      AlertsScreen(),
      MarketScreen(),
      SettingsScreen(),
      profileTab,
    ];

    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
            tooltip: isUrdu ? 'ہوم ڈیش بورڈ' : 'Home dashboard',
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: AppLocalizations.of(context)!.forecast,
            tooltip: isUrdu ? 'موسمی پیشن گوئی' : 'Weather forecast',
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
                tooltip:
                    count > 0
                        ? (isUrdu
                            ? '$count غیر پڑھے الرٹس'
                            : '$count unread alerts')
                        : (isUrdu ? 'موسمی الرٹس' : 'Weather alerts'),
              );
            },
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: isUrdu ? 'مارکیٹ' : 'Market',
            tooltip: isUrdu ? 'مارکیٹ پلیس' : 'Marketplace',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
            tooltip: isUrdu ? 'ایپ ترتیبات' : 'App settings',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: isUrdu ? 'پروفائل' : 'Profile',
            tooltip: isUrdu ? 'پروفائل' : 'Profile',
          ),
        ],
      ),
    );
  }
}
