import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'location_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/market_api_service.dart';
import '../services/firebase_service.dart';
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
          display +=
              '\n(${profile.latitude!.toStringAsFixed(4)}, ${profile.longitude!.toStringAsFixed(4)})';
        }
        if (profile.locationUpdatedAt != null) {
          display +=
              '\nUpdated: ${_formatTimestamp(profile.locationUpdatedAt!.toIso8601String())}';
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Enable notifications?'),
              content: const Text(
                'We use push notifications for new offers, new messages, and weather alerts that may affect your crops.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not now'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Allow'),
                ),
              ],
            ),
      );

      if (confirmed != true) {
        await _updateNotificationSetting(false);
        return;
      }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_rounded, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.settings,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, AppColors.background],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade700, Colors.green.shade500],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade700.withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App preferences',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Notifications, location, and support controls in one place.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_notificationsEnabled)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_outlined,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Push notifications are off',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enable them to receive offers, chat messages, and weather alerts in time.',
                            style: TextStyle(
                              color: Colors.orange.shade900.withOpacity(0.85),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _handleNotificationToggle(true),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.notifications,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Control alerts and push notifications',
                    ),
                    value: _notificationsEnabled,
                    onChanged: _handleNotificationToggle,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.location,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_savedLocation),
                    trailing: const Icon(Icons.chevron_right_rounded),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.info, color: Colors.green.shade700),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.aboutApp,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Version 1.0\nDigital Kissan App for smart agriculture.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.contactSupport,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Get help with account or app issues'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (kDebugMode)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_upload,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  title: const Text(
                    'Save sample data to Firebase',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
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
              ),
            if (kDebugMode) const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.green.shade700,
                  ),
                ),
                title: const Text(
                  'Show Test Notification',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Send a local notification to verify the channel',
                ),
                onTap: () async {
                  final notificationService = Provider.of<NotificationService>(
                    context,
                    listen: false,
                  );
                  final sent = await notificationService.showNotification(
                    title: 'Test Notification',
                    body:
                        'This is a test notification from Digital Kissan App.',
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
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded, color: Colors.red.shade600),
                ),
                title: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
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
            ),
          ],
        ),
      ),
    );
  }
}
