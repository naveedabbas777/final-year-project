import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart'; // Import for debugPrint
import 'package:flutter/foundation.dart'; // Import for defaultTargetPlatform
import 'package:shared_preferences/shared_preferences.dart'; // Import for SharedPreferences
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const String _kNotificationsEnabled = 'notifications_enabled';

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Setup FCM foreground message handling to show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM message received (foreground): ${message.messageId}');
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: message.data.isNotEmpty ? message.data.toString() : null,
        );
      }
    });
  }

  Future<bool> requestNotificationPermissions() async {
    // Also request FCM permissions on iOS and Android 13+
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('Error requesting FCM permission: $e');
    }
    // Check if permission is already granted for Android 13+
    // On older Android versions, permission is granted at install time.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        final bool? granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    }

    // For iOS, use permission_handler as flutter_local_notifications doesn't handle it directly well
    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Returns the FCM token for this device (useful to register token on server)
  Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }

  Future<bool> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? true;

    if (!notificationsEnabled) {
      debugPrint(
        'Notifications are disabled by user, skipping local notification.',
      );
      return false; // Indicate that notification was skipped
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          channelDescription: 'your_channel_description',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    return true; // Indicate that notification was sent
  }
}
