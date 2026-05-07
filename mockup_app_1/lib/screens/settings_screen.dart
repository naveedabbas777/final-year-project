import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firebase_service.dart';
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
      if (mounted) {
        setState(() {
          _savedLocation = 'No location set';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _savedLocation = 'Loading location...';
      });
    }

    try {
      // Try to load from Firebase first
      final doc = await _firebaseService.getUserByUid(user.uid);
      final address = doc?['address'] as String?;
      final lat = (doc?['lat'] as num?)?.toDouble();
      final lon = (doc?['lon'] as num?)?.toDouble();
      final locationUpdatedAt = doc?['locationUpdatedAt'] as String?;

      String display = 'No location set';
      if (address != null && address.isNotEmpty && lat != null && lon != null) {
        display =
            '$address\n(${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';
        if (locationUpdatedAt != null && locationUpdatedAt.isNotEmpty) {
          display += '\nUpdated: ${_formatTimestamp(locationUpdatedAt)}';
        }
      } else if (address?.isNotEmpty == true) {
        display = address!;
      }

      if (mounted) {
        setState(() {
          _savedLocation = display;
        });
      }
    } catch (e) {
      debugPrint(
        'Failed to load from Firebase: $e. Trying SharedPreferences...',
      );

      // Fallback: Try to load from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final lat = prefs.getDouble('last_latitude');
        final lng = prefs.getDouble('last_longitude');
        final address = prefs.getString('last_address');

        String display = 'No location set';
        if (address != null &&
            address.isNotEmpty &&
            lat != null &&
            lng != null) {
          display =
              '$address\n(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
        }

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

  @override
  Widget build(BuildContext context) {
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
