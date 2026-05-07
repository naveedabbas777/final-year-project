import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';

class FirebaseService {
  FirebaseService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Writes a simple message through the backend.
  Future<void> writeSampleMessage(String message) async {
    await _client.post('/api/messages', auth: true, body: {'message': message});
  }

  /// Reads the last N messages through the backend.
  Future<List<Map<String, dynamic>>> readLastMessages({int limit = 20}) async {
    final data = await _client.get(
      '/api/messages',
      auth: true,
      query: {'limit': limit.toString()},
    );
    if (data is! List<dynamic>) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Polling-based stream for live updates from the backend.
  Stream<List<Map<String, dynamic>>> messagesStream({int limit = 50}) async* {
    yield await readLastMessages(limit: limit);
    yield* Stream.periodic(
      const Duration(seconds: 10),
    ).asyncMap((_) => readLastMessages(limit: limit));
  }

  /// Ensure the backend creates or refreshes the current user profile.
  Future<void> createUserIfNotExists(
    User user, {
    String? displayName,
    String? phoneNumber,
    String? address,
    double? lat,
    double? lon,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
      payload['name'] = displayName.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      payload['phoneNumber'] = phoneNumber.trim();
      payload['phone'] = phoneNumber.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      payload['address'] = address.trim();
    }
    if (lat != null) {
      payload['lat'] = lat;
    }
    if (lon != null) {
      payload['lon'] = lon;
    }
    if (payload.isNotEmpty) {
      await _client.patch('/api/users/me', auth: true, body: payload);
    }
    await _client.get('/api/users/me', auth: true);
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber) async {
    try {
      final data = await _client.get(
        '/api/users/by-phone/$phoneNumber',
        auth: true,
      );
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final data = await _client.get('/api/users/$uid', auth: true);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserProfile(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['displayName'] = displayName;
      updates['name'] = displayName;
    }
    if (phoneNumber != null) {
      updates['phoneNumber'] = phoneNumber;
      updates['phone'] = phoneNumber;
    }
    if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
      updates['photo'] = photoUrl;
    }
    if (updates.isNotEmpty) {
      await _client.patch('/api/users/me', auth: true, body: updates);
    }
  }

  Future<void> updateUserLocation(
    String uid, {
    String? address,
    double? lat,
    double? lon,
  }) async {
    final updates = <String, dynamic>{};
    if (address != null && address.trim().isNotEmpty) {
      updates['address'] = address.trim();
    }
    if (lat != null) {
      updates['lat'] = lat;
    }
    if (lon != null) {
      updates['lon'] = lon;
    }
    if (updates.isNotEmpty) {
      await _client.patch('/api/users/me', auth: true, body: updates);
    }
  }

  Future<void> updateNotificationPreference(String uid, bool enabled) async {
    await _client.patch(
      '/api/users/me',
      auth: true,
      body: {'notificationsEnabled': enabled},
    );
  }

  Future<void> updateUserNotificationData(
    String uid, {
    String? fcmToken,
    bool? notificationsEnabled,
    double? lat,
    double? lon,
    String? address,
    DateTime? lastNotifiedAt,
  }) async {
    if (fcmToken != null && fcmToken.trim().isNotEmpty) {
      await _client.post(
        '/api/users/me/fcm-token',
        auth: true,
        body: {'token': fcmToken.trim()},
      );
    }

    final updates = <String, dynamic>{};
    if (notificationsEnabled != null) {
      updates['notificationsEnabled'] = notificationsEnabled;
    }
    if (lat != null) updates['lat'] = lat;
    if (lon != null) updates['lon'] = lon;
    if (address != null) updates['address'] = address;
    if (lastNotifiedAt != null) {
      updates['lastNotifiedAt'] = lastNotifiedAt.toIso8601String();
    }

    if (updates.isNotEmpty) {
      await _client.patch('/api/users/me', auth: true, body: updates);
    }
  }
}
