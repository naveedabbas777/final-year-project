import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'market_api_service.dart';

/// Global navigator key used by PushService to navigate on notification tap.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PushService {
  PushService._();
  static final instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final _api = MarketApiService();

  // Android notification channels
  static const _offerChannel = AndroidNotificationChannel(
    'offers_channel',
    'Offers',
    description: 'Notifications about offers on your listings',
    importance: Importance.high,
  );

  static const _messageChannel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
  );

  static const _orderChannel = AndroidNotificationChannel(
    'orders_channel',
    'Orders',
    description: 'Order status updates',
    importance: Importance.defaultImportance,
  );

  static const _defaultChannel = AndroidNotificationChannel(
    'default_channel',
    'General',
    description: 'General notifications',
    importance: Importance.high,
  );

  static const _weatherChannel = AndroidNotificationChannel(
    'weather_channel',
    'Weather Alerts',
    description: 'Weather conditions affecting your crops',
    importance: Importance.high,
  );

  Future<void> init() async {
    // Request permission on iOS / Android 13+
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create Android notification channels
    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_offerChannel);
      await androidPlugin.createNotificationChannel(_messageChannel);
      await androidPlugin.createNotificationChannel(_orderChannel);
      await androidPlugin.createNotificationChannel(_weatherChannel);
      await androidPlugin.createNotificationChannel(_defaultChannel);
    }

    // Initialize local notifications with tap handler
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

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
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      try {
        await _api.registerDeviceToken(newToken);
      } catch (_) {}
    });

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

    // Handle cold-start notification tap
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      // Delay to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 800), () {
        _handleNotificationNavigation(initialMessage);
      });
    }
  }

  /// Show a local notification when a foreground FCM message arrives.
  Future<void> _handleForegroundMessage(RemoteMessage msg) async {
    final nt = msg.notification;
    final title = nt?.title ?? msg.data['title'] ?? 'Notification';
    final body = nt?.body ?? msg.data['body'] ?? '';
    final type = msg.data['type'] ?? '';

    // Choose channel based on notification type
    final channel = _channelForType(type);

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Encode data payload for tap handling
    final payload = jsonEncode(msg.data);

    await _local.show(
      msg.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Called when user taps a local notification.
  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateForData(data);
    } catch (e) {
      debugPrint('Failed to parse notification payload: $e');
    }
  }

  /// Called when user taps FCM notification (background/terminated).
  void _handleNotificationNavigation(RemoteMessage message) {
    _navigateForData(message.data);
  }

  /// Route to the appropriate screen based on notification data.type.
  void _navigateForData(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[PushService] Navigator not available for deep link');
      return;
    }

    switch (type) {
      case 'offer':
      case 'offer_accepted':
      case 'offer_rejected':
        // Navigate to offers screen
        navigator.pushNamed('/offers');
        break;
      case 'message':
        // Navigate to chat if we have listingId
        final listingId = data['listingId'] ?? '';
        if (listingId.isNotEmpty) {
          navigator.pushNamed('/chat', arguments: {'listingId': listingId});
        } else {
          navigator.pushNamed('/market');
        }
        break;
      case 'listing_status':
        navigator.pushNamed('/my-listings');
        break;
      case 'order_status':
        navigator.pushNamed('/orders');
        break;
      case 'admin_notice':
      case 'weather_alert':
        navigator.pushNamed('/alerts');
        break;
      default:
        debugPrint('[PushService] Unknown notification type: $type');
    }
  }

  /// Pick the right Android notification channel based on type.
  AndroidNotificationChannel _channelForType(String type) {
    switch (type) {
      case 'offer':
      case 'offer_accepted':
      case 'offer_rejected':
        return _offerChannel;
      case 'message':
        return _messageChannel;
      case 'order_status':
        return _orderChannel;
      case 'weather_alert':
        return _weatherChannel;
      default:
        return _defaultChannel;
    }
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
