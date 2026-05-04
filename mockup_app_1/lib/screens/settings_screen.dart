import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_screen.dart';
import 'package:permission_handler/permission_handler.dart'; // Uncomment this import
import '../services/firebase_service.dart';
import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/notification_service.dart'; // Import the new service

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _savedLocation = 'No location set';
  bool _notificationsEnabled = true;
  static const String _kNotificationsEnabled = 'notifications_enabled';
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _loadNotificationSetting();
  }

  Future<void> _loadSaved() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      setState(() {
        _savedLocation = 'No location set';
      });
      return;
    }

    setState(() {
      _savedLocation = 'Loading location...';
    });

    try {
      final doc = await _firebaseService.getUserByUid(user.uid);
      final address = doc?['address'] as String?;
      final lat = (doc?['lat'] as num?)?.toDouble();
      final lon = (doc?['lon'] as num?)?.toDouble();

      final display =
          (address != null && address.isNotEmpty && lat != null && lon != null)
              ? '$address (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})'
              : (address?.isNotEmpty == true ? address! : 'No location set');

      if (mounted) {
        setState(() {
          _savedLocation = display;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _savedLocation = 'No location set';
        });
      }
    }
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPreference = prefs.getBool(_kNotificationsEnabled) ?? true;
    final PermissionStatus systemStatus = await Permission.notification.status;

    setState(() {
      // Combine stored preference with actual system permission status
      _notificationsEnabled = storedPreference && systemStatus.isGranted;
    });
  }

  Future<void> _handleNotificationToggle(bool value) async {
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    if (value) {
      // Request permission using the new NotificationService
      final bool granted =
          await notificationService.requestNotificationPermissions();

      if (granted) {
        await _updateNotificationSetting(true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notifications enabled.')));
      } else {
        // If denied, or restricted, check if permanently denied to guide to settings
        final PermissionStatus status = await Permission.notification.status;
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        } else {
          await _updateNotificationSetting(false); // Update local state to off
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Notification permission was denied. Enable in settings?',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
      }
    } else {
      // Directly disable if the user toggles it off
      await _updateNotificationSetting(false);
    }
  }

  Future<void> _updateNotificationSetting(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, isEnabled);
    setState(() {
      _notificationsEnabled = isEnabled;
    });

    // Update notification preference in FirebaseService
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user != null) {
      final firebaseService = FirebaseService();
      await firebaseService.updateNotificationPreference(user.uid, isEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLocale = languageProvider.locale;
    final currentLanguageString =
        currentLocale.languageCode == 'en' ? 'English' : 'Urdu';
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.green.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (user != null)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.green.shade700),
                  title: Text(
                    user.phoneNumber ?? 'User: ${user.uid.substring(0, 6)}',
                  ),
                  subtitle: Text(
                    user.isAnonymous ? 'Signed in as Guest' : 'Signed in',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await auth.signOut();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')),
                      );
                    },
                    child: const Text('Sign out'),
                  ),
                ),
              ),
            ListTile(
              leading: Icon(Icons.language, color: Colors.green.shade700),
              title: Text(AppLocalizations.of(context)!.language),
              trailing: DropdownButton<String>(
                value: currentLanguageString,
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Urdu', child: Text('Urdu')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    final newLocale =
                        newValue == 'English'
                            ? const Locale('en', '')
                            : const Locale('ur', '');
                    languageProvider.setLocale(newLocale);
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.notifications,
                color: Colors.green.shade700,
              ),
              title: Text(AppLocalizations.of(context)!.notifications),
              value: _notificationsEnabled,
              onChanged: _handleNotificationToggle,
            ),
            ListTile(
              leading: Icon(Icons.location_on, color: Colors.green.shade700),
              title: Text(AppLocalizations.of(context)!.location),
              subtitle: Text(_savedLocation),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LocationScreen(),
                  ),
                );
                await _loadSaved();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info, color: Colors.green.shade700),
              title: Text(AppLocalizations.of(context)!.aboutApp),
              subtitle: const Text(
                'Version 1.0\nDigital Kissan App for smart agriculture.',
              ),
            ),
            ListTile(
              leading: Icon(Icons.support_agent, color: Colors.green.shade700),
              title: Text(AppLocalizations.of(context)!.contactSupport),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.cloud_upload, color: Colors.green.shade700),
              title: const Text('Save sample data to Firebase'),
              onTap: () async {
                final service = FirebaseService();
                try {
                  await service.writeSampleMessage('Hello from device');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved sample message to Firebase'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save to Firebase: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(
                Icons.notifications_active,
                color: Colors.green.shade700,
              ),
              title: const Text('Show Test Notification'),
              onTap: () async {
                final notificationService = Provider.of<NotificationService>(
                  context,
                  listen: false,
                );
                final sent = await notificationService.showNotification(
                  title: 'Test Notification',
                  body: 'This is a test notification from Digital Kissan App.',
                  payload: 'test_notification_payload',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent
                            ? 'Test notification sent!'
                            : 'Notifications are off. Enable them in settings to receive notifications.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
