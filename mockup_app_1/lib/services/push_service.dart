import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'market_api_service.dart';

class PushService {
  PushService._();
  static final instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final _api = MarketApiService();

  Future<void> init() async {
    // Request permission on iOS
    await _messaging.requestPermission();

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    // Get token and register with backend
    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _api.registerDeviceToken(token);
      } catch (_) {
        // ignore backend registration errors
      }
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final nt = msg.notification;
      final title = nt?.title ?? msg.data['title'] ?? 'Notification';
      final body = nt?.body ?? msg.data['body'] ?? '';

      const androidDetails = AndroidNotificationDetails(
        'default',
        'Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await _local.show(0, title, body, details, payload: msg.data.toString());
    });

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _api.registerDeviceToken(newToken);
      } catch (_) {}
    });
  }

  Future<void> dispose() async {
    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _api.unregisterDeviceToken(token);
      } catch (_) {}
    }
  }
}
