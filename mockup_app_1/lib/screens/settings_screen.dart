import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockup_app/l10n/app_localizations.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/providers/language_provider.dart';
import 'location_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/market_api_service.dart';
import '../services/firebase_service.dart';
import '../widgets/confirm_dialog.dart';
import 'package:mockup_app/widgets/help_guide_dialog.dart';
import 'package:mockup_app/widgets/comprehensive_help_dialog.dart';
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

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

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
      if (mounted)
        setState(
          () => _savedLocation = _t('No location set', 'مقام سیٹ نہیں ہے'),
        );
      return;
    }
    if (mounted) {
      setState(
        () =>
            _savedLocation = _t('Loading location...', 'مقام لوڈ ہو رہا ہے...'),
      );
    }
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
              '\n${_t('Updated', 'اپ ڈیٹ')}: ${_formatTimestamp(profile.locationUpdatedAt!.toIso8601String())}';
        }
      } else if (profile.district.isNotEmpty) {
        display = profile.locationSummary;
      }
      if (mounted) setState(() => _savedLocation = display);
    } catch (e) {
      if (kDebugMode) debugPrint('[Settings] Failed to load location: $e');
      if (mounted)
        setState(
          () => _savedLocation = _t('No location set', 'مقام سیٹ نہیں ہے'),
        );
    }
  }

  String _formatTimestamp(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return Localizations.localeOf(context).languageCode == 'ur'
            ? '${difference.inMinutes} منٹ پہلے'
            : '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return Localizations.localeOf(context).languageCode == 'ur'
            ? '${difference.inHours} گھنٹے پہلے'
            : '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return Localizations.localeOf(context).languageCode == 'ur'
            ? '${difference.inDays} دن پہلے'
            : '${difference.inDays}d ago';
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
              title: Text(_t('Enable notifications?', 'اطلاعات فعال کریں؟')),
              content: Text(
                _t(
                  'We use push notifications for new offers, new messages, and weather alerts that may affect your crops.',
                  'ہم نئی آفرز، نئے پیغامات اور موسمی الرٹس کے لیے پش نوٹیفکیشنز استعمال کرتے ہیں۔',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t('Not now', 'ابھی نہیں')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_t('Allow', 'اجازت دیں')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('Notifications enabled.', 'اطلاعات فعال ہو گئیں۔'),
            ),
          ),
        );
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
                label: _t('Settings', 'ترتیبات'),
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
      message: _t(
        'Are you sure you want to sign out?',
        'کیا آپ واقعی سائن آؤٹ کرنا چاہتے ہیں؟',
      ),
      confirmLabel: _t('Sign Out', 'سائن آؤٹ'),
      isDangerous: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed != true) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguageString =
        languageProvider.locale.languageCode == 'en' ? 'English' : 'Urdu';

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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: _t('Help', 'مدد'),
              onPressed: () => showHelpGuide(context, 'settings'),
              icon: const Icon(Icons.help_outline, size: 20),
            ),
          ),
        ],
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
                        Text(
                          _t('App preferences', 'ایپ ترجیحات'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t(
                            'Notifications, location, and support controls in one place.',
                            'اطلاعات، مقام اور مدد کی ترتیبات ایک جگہ۔',
                          ),
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
                            _t(
                              'Push notifications are off',
                              'پش اطلاعات بند ہیں',
                            ),
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _t(
                              'Enable them to receive offers, chat messages, and weather alerts in time.',
                              'آفرز، چیٹ پیغامات اور موسمی الرٹس بروقت حاصل کرنے کے لیے انہیں فعال کریں۔',
                            ),
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
                      child: Text(_t('Enable', 'فعال کریں')),
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
                    subtitle: Text(
                      _t(
                        'Control alerts and push notifications',
                        'الرٹس اور پش اطلاعات کو کنٹرول کریں',
                      ),
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
                      child: Icon(Icons.language, color: Colors.green.shade700),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.languageLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _t(
                        'Choose app display language',
                        'ایپ کی زبان منتخب کریں',
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: currentLanguageString,
                      underline: const SizedBox.shrink(),
                      dropdownColor: AppColors.surface,
                      iconEnabledColor: AppColors.textPrimary,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'English',
                          child: Text(
                            'English',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Urdu',
                          child: Text(
                            'Urdu',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue == null) return;
                        languageProvider.setLocale(
                          newValue == 'English'
                              ? const Locale('en', '')
                              : const Locale('ur', ''),
                        );
                      },
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
                    subtitle: Text(
                      _t(
                        'Version 1.0\nDigital Kissan App for smart agriculture.',
                        'ورژن 1.0\nسمارٹ زراعت کے لیے ڈیجیٹل کسان ایپ۔',
                      ),
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
                        Icons.help_outline,
                        color: Colors.green.shade700,
                      ),
                    ),
                    title: Text(
                      _t('Complete App Guide', 'مکمل ایپ گائیڈ'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _t(
                        'Learn how to use all app features',
                        'ایپ کی تمام خصوصیات استعمال کرنا سیکھیں',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ComprehensiveHelpDialog(),
                      );
                    },
                  ),
                  const Divider(height: 1),
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
                  title: Text(
                    _t(
                      'Save sample data to Firebase',
                      'نمونہ ڈیٹا فائر بیس میں محفوظ کریں',
                    ),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(_t('DEV ONLY', 'صرف ڈویلپمنٹ')),
                  onTap: () async {
                    final service = FirebaseService();
                    try {
                      await service.writeSampleMessage('Hello from device');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _t(
                                'Saved sample message to Firebase',
                                'نمونہ پیغام فائر بیس میں محفوظ ہو گیا',
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_t('Failed to save to Firebase', 'فائر بیس میں محفوظ نہ ہو سکا')}: $e',
                            ),
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
                title: Text(
                  _t('Show Test Notification', 'ٹیسٹ اطلاع دکھائیں'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _t(
                    'Send a local notification to verify the channel',
                    'چینل چیک کرنے کے لیے مقامی اطلاع بھیجیں',
                  ),
                ),
                onTap: () async {
                  final notificationService = Provider.of<NotificationService>(
                    context,
                    listen: false,
                  );
                  final sent = await notificationService.showNotification(
                    title: _t('Test Notification', 'ٹیسٹ اطلاع'),
                    body: _t(
                      'This is a test notification from Digital Kissan App.',
                      'یہ ڈیجیٹل کسان ایپ کی ٹیسٹ اطلاع ہے۔',
                    ),
                    payload: 'test_notification_payload',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          sent
                              ? _t(
                                'Test notification sent!',
                                'ٹیسٹ اطلاع بھیج دی گئی!',
                              )
                              : _t(
                                'Notifications are off. Enable them in settings to receive notifications.',
                                'اطلاعات بند ہیں۔ اطلاعات حاصل کرنے کے لیے انہیں ترتیبات میں فعال کریں۔',
                              ),
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
                  _t('Sign Out', 'سائن آؤٹ'),
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _t(
                    'Sign out of your account',
                    'اپنے اکاؤنٹ سے سائن آؤٹ کریں',
                  ),
                ),
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
