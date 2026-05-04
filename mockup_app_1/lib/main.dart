import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:provider/provider.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/notification_service.dart'; // Import the new service
import 'package:mockup_app/services/alert_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'; // Import for MapboxOptions
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

  const mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  if (mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxAccessToken);
  } else {
    debugPrint('MAPBOX_ACCESS_TOKEN is not set; Mapbox features may fail.');
  }

  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();

  // Register background handler for FCM messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (iOS / Android 13+)
  await notificationService.requestNotificationPermissions();

  // Print / log FCM token for debugging (register on server if needed)
  final fcmToken = await notificationService.getFcmToken();
  debugPrint('FCM Token: $fcmToken');

  // Handle messages that opened the app from a terminated state
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      debugPrint(
        'App opened from terminated state by message: ${message.messageId}',
      );
    }
  });

  // Handle when a user taps a notification and the app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Message caused app to open: ${message.messageId}');
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ur', ''), // Urdu
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme().copyWith(
          // Use Noto Sans for better Urdu support
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
    await Future.delayed(
      const Duration(seconds: 2),
    ); // Keep splash screen visible for 2 seconds

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isSignedIn) {
      // User is already signed in, navigate to main shell
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationShell()),
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
          MaterialPageRoute(builder: (context) => const MainNavigationShell()),
        );
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
      body: _screens[_selectedIndex],
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
