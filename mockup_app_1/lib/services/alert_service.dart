import 'package:flutter/material.dart';

import 'api_client.dart';

class AlertItem {
  final String id;
  final String type; // rain | heat | cold | wind | admin_notice
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    // Safely parse every field — the Firestore serializer can emit nulls
    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';

    String? createdAtRaw = json['createdAt']?.toString();
    DateTime createdAt;
    try {
      createdAt =
          createdAtRaw != null ? DateTime.parse(createdAtRaw) : DateTime.now();
    } catch (_) {
      createdAt = DateTime.now();
    }

    return AlertItem(
      id: id,
      type: json['type']?.toString() ?? 'info',
      title: json['title']?.toString() ?? 'Alert',
      body: json['body']?.toString() ?? '',
      createdAt: createdAt,
      isRead: json['read'] == true,
    );
  }
}

class AlertService extends ChangeNotifier {
  AlertService() : _client = ApiClient();

  final ApiClient _client;
  final List<AlertItem> _alerts = [];
  bool _loaded = false;
  bool _loading = false;

  List<AlertItem> get alerts => List.unmodifiable(_alerts);

  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  bool get isLoading => _loading;

  Future<void> loadAlerts() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final data = await _client.get('/api/alerts', auth: true);
      final list =
          data is List<dynamic>
              ? data
                  .whereType<Map<String, dynamic>>()
                  .map(AlertItem.fromJson)
                  .toList()
              : <AlertItem>[];
      _alerts
        ..clear()
        ..addAll(list);
    } catch (_) {
      // Keep existing list on failure
    } finally {
      _loading = false;
      _loaded = true;
      notifyListeners();
    }
  }

  /// Optimistically marks an alert as read locally, then persists to backend.
  Future<void> markAsRead(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return;
    if (_alerts[index].isRead) return;

    // Optimistic update
    final old = _alerts[index];
    _alerts[index] = AlertItem(
      id: old.id,
      type: old.type,
      title: old.title,
      body: old.body,
      createdAt: old.createdAt,
      isRead: true,
    );
    notifyListeners();

    try {
      await _client.patch('/api/alerts/$alertId/read', body: {}, auth: true);
    } catch (_) {
      // Rollback on failure
      _alerts[index] = old;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final unread = _alerts.where((a) => !a.isRead).toList();
    for (final alert in unread) {
      await markAsRead(alert.id);
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await loadAlerts();
  }

  Future<List<AlertItem>> processWeather(_, __) async {
    await _ensureLoaded();
    return _alerts;
  }
}
