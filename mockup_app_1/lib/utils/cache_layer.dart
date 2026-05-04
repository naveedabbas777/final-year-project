import 'dart:async';

/// Simple in-memory cache with TTL support
class CacheLayer<K, V> {
  final Map<K, _CacheEntry<V>> _store = {};
  final Duration ttl;

  CacheLayer({Duration? ttl}) : ttl = ttl ?? const Duration(minutes: 5);

  /// Gets a value from cache if it exists and hasn't expired
  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }

    return entry.value;
  }

  /// Sets a value in cache with TTL
  void set(K key, V value) {
    _store[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
  }

  /// Gets or fetches a value
  /// If found in cache and not expired, returns cached value
  /// Otherwise calls the fetch function, caches result, and returns it
  Future<V> getOrFetch(K key, Future<V> Function() fetch) async {
    final cached = get(key);
    if (cached != null) {
      return cached;
    }

    final value = await fetch();
    set(key, value);
    return value;
  }

  /// Clears a specific key from cache
  void invalidate(K key) {
    _store.remove(key);
  }

  /// Clears all cache entries
  void clear() {
    _store.clear();
  }

  /// Clears expired entries
  void removeExpired() {
    final now = DateTime.now();
    _store.removeWhere((key, entry) => now.isAfter(entry.expiresAt));
  }

  /// Returns number of cached entries
  int get length => _store.length;
}

class _CacheEntry<V> {
  final V value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});
}

/// Global cache instances for common use cases
class AppCaches {
  static final weather = CacheLayer<String, dynamic>(
    ttl: const Duration(minutes: 10),
  );
  static final market = CacheLayer<String, dynamic>(
    ttl: const Duration(minutes: 5),
  );
  static final userProfile = CacheLayer<String, dynamic>(
    ttl: const Duration(minutes: 30),
  );
}
