import 'package:flutter/material.dart';
import 'package:mockup_app/l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      // Navigation will be handled in main.dart
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade100,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 80, color: Colors.green.shade800),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.appTitle,
              textDirection:
                  AppLocalizations.of(context)!.localeName == 'ur'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.appTagline,
              textDirection:
                  AppLocalizations.of(context)!.localeName == 'ur'
                      ? TextDirection.rtl
                      : TextDirection.ltr,
              style: TextStyle(fontSize: 16, color: Colors.green.shade700),
            ),
            const SizedBox(height: 30),
            CircularProgressIndicator(color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }
}
