import 'dart:async';
import 'api_client.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final ApiClient _apiClient = ApiClient();
  bool _isBackendReachable = true;
  final _statusStream = StreamController<bool>.broadcast();
  Timer? _periodicTimer;

  /// Stream that emits backend connectivity status changes
  Stream<bool> get statusStream => _statusStream.stream;

  /// Get current connectivity status without waiting
  bool get isBackendReachable => _isBackendReachable;

  /// Check if backend is reachable with a single health check
  Future<bool> checkBackendHealth({Duration? timeout}) async {
    try {
      await _apiClient
          .get('/api/health')
          .timeout(
            timeout ?? const Duration(seconds: 5),
            onTimeout:
                () => throw TimeoutException('Backend health check timed out'),
          );

      if (!_isBackendReachable) {
        _isBackendReachable = true;
        _statusStream.add(true);
      }

      return true;
    } catch (e) {
      if (_isBackendReachable) {
        _isBackendReachable = false;
        _statusStream.add(false);
      }
      return false;
    }
  }

  /// Start periodic health checks.
  /// Cancels any previously running periodic timer before starting a new one.
  void startPeriodicHealthCheck({
    Duration interval = const Duration(seconds: 30),
  }) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      await checkBackendHealth();
    });
  }

  /// Dispose resources
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _statusStream.close();
  }
}
