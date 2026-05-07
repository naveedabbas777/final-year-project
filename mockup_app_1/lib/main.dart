import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
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
  const DigitalKissanApp({Key? key}) : super(key: key);

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme().copyWith(
          bodyLarge: GoogleFonts.notoSans(),
          bodyMedium: GoogleFonts.notoSans(),
          bodySmall: GoogleFonts.notoSans(),
          titleLarge: GoogleFonts.notoSans(),
          titleMedium: GoogleFonts.notoSans(),
          titleSmall: GoogleFonts.notoSans(),
        ),
      ),
      home: const SplashScreenWrapper(),
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

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({Key? key}) : super(key: key);

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Keep splash screen visible for a short moment while bootstrapping
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );

    // Wait for auth provider to finish bootstrap, with a bounded timeout
    if (!authProvider.isBootstrapComplete) {
      final completer = Completer<void>();
      void listener() {
        if (authProvider.isBootstrapComplete && !completer.isCompleted) {
          completer.complete();
        }
      }

      authProvider.addListener(listener);

      // Wait up to 5 seconds for bootstrap; proceed after timeout to avoid hang
      await Future.any([
        completer.future,
        Future.delayed(const Duration(seconds: 5)),
      ]);

      authProvider.removeListener(listener);
    }

    if (!mounted) return;

    if (authProvider.isSignedIn) {
      // User is already signed in, route based on role.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleBasedHomeScreen()),
      );
    } else {
      // User is not signed in, navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreenWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

class LoginScreenWrapper extends StatelessWidget {
  const LoginScreenWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      onLogin: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleBasedHomeScreen()),
        );
      },
    );
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
            icon: Icon(Icons.home),
            label: AppLocalizations.of(context)!.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: AppLocalizations.of(context)!.forecast,
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: AppLocalizations.of(context)!.alerts,
          ),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Market'),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
      ),
    );
  }
}
