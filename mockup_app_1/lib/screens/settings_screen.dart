import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'location_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/market_api_service.dart';
import '../widgets/confirm_dialog.dart';
import 'package:mockup_app/providers/auth_provider.dart';
import 'package:mockup_app/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _savedLocation = 'No location set';
  bool _notificationsEnabled = true;
  static const String _kNotificationsEnabled = 'notifications_enabled';
  final _marketApi = MarketApiService();

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _loadNotificationSetting();
  }

  /// Loads the user's saved location from the market API (same source as profile screen).
  Future<void> _loadSaved() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      if (mounted) setState(() => _savedLocation = 'No location set');
      return;
    }
    if (mounted) setState(() => _savedLocation = 'Loading location...');
    try {
      final profile = await _marketApi.fetchMe();
      String display = 'No location set';
      if (profile.address.isNotEmpty) {
        display = profile.address;
        if (profile.latitude != null && profile.longitude != null) {
          display += '\n(${profile.latitude!.toStringAsFixed(4)}, ${profile.longitude!.toStringAsFixed(4)})';
        }
        if (profile.locationUpdatedAt != null) {
          display += '\nUpdated: ${_formatTimestamp(profile.locationUpdatedAt!.toIso8601String())}';
        }
      } else if (profile.district.isNotEmpty) {
        display = profile.locationSummary;
      }
      if (mounted) setState(() => _savedLocation = display);
    } catch (e) {
      if (kDebugMode) debugPrint('[Settings] Failed to load location: $e');
      if (mounted) setState(() => _savedLocation = 'No location set');
    }
  }


  String _formatTimestamp(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return dateTime.toString().split('.')[0];
      }
    } catch (_) {
      return '';
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

  /// Unified sign-out with confirmation dialog
  Future<void> _signOut() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDangerous: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed != true) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.settings,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade800, Colors.green.shade600],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7F5),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
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
            if (kDebugMode) ...
              [
                ListTile(
                  leading: Icon(
                    Icons.cloud_upload,
                    color: Colors.green.shade700,
                  ),
                  title: const Text('Save sample data to Firebase'),
                  subtitle: const Text('DEV ONLY'),
                  onTap: () async {
                    final service = FirebaseService();
                    try {
                      await service.writeSampleMessage('Hello from device');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saved sample message to Firebase'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save to Firebase: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
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
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: Colors.red.shade600),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Sign out of your account'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.red.shade300,
              ),
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}
