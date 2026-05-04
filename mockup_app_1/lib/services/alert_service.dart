import 'package:flutter/material.dart';

import 'api_client.dart';
import 'weather_service.dart';

class AlertItem {
  final String id;
  final String type; // e.g., rain, heat, cold, wind
  final String title;
  final String body;
  final DateTime createdAt;

  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
  };
}

class AlertService extends ChangeNotifier {
  AlertService() : _client = ApiClient();

  final ApiClient _client;
  final List<AlertItem> _alerts = [];
  bool _loaded = false;

  List<AlertItem> get alerts => List.unmodifiable(_alerts);

  Future<void> loadAlerts() async {
    try {
      final data = await _client.get('/api/alerts', auth: true);
      final list =
          data is List<dynamic>
              ? data.whereType<Map<String, dynamic>>().map(AlertItem.fromJson).toList()
              : <AlertItem>[];
      _alerts
        ..clear()
        ..addAll(list);
    } catch (_) {
      _alerts.clear();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> clearAlerts() async {
    await _ensureLoaded();
    _alerts.clear();
    notifyListeners();
  }

  Future<List<AlertItem>> processWeather(
    CurrentWeather? current,
    DailyForecast? todayForecast,
  ) async {
    await loadAlerts();
    return _alerts;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await loadAlerts();
  }
}
