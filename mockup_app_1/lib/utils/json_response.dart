Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

/// DTO parsing helpers to reduce null-coalescing boilerplate
/// Returns empty string for null or invalid values
String toStringOrEmpty(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  if (value == null) return '';
  return value.toString();
}

/// Returns 0.0 for null or invalid numeric values
double toDoubleOrZero(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return 0.0;
}

/// Returns 0 for null or invalid numeric values
int toIntOrZero(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return 0;
}

/// Parses ISO 8601 date strings, returns current time if parsing fails
DateTime toDateTimeOrNow(dynamic value) {
  if (value is DateTime) return value;
  if (value is Map && value['seconds'] is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value['seconds'] as num).toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

/// Returns null for null or invalid numeric values, otherwise returns double
double? toDoubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

/// Returns List<String> with empty values filtered out
List<String> toStringListOrEmpty(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((e) => e is String ? e : e?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}
