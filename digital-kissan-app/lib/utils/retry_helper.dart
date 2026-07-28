import 'dart:async';
import 'dart:math';

/// Retry helper with exponential backoff strategy
class RetryHelper {
  /// Retries an async operation with exponential backoff
  ///
  /// Parameters:
  /// - operation: The async function to retry
  /// - maxAttempts: Maximum number of retry attempts (default: 3)
  /// - initialDelayMs: Initial delay before first retry in milliseconds (default: 500)
  /// - maxDelayMs: Maximum delay between retries (default: 5000)
  /// - jitterFraction: Fraction of delay to add as random jitter (default: 0.1)
  /// - onRetry: Optional callback when a retry happens
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    int initialDelayMs = 500,
    int maxDelayMs = 5000,
    double jitterFraction = 0.1,
    Function(int attemptNumber, Duration delay)? onRetry,
  }) async {
    ArgumentError.checkNotNull(operation);
    assert(maxAttempts > 0);
    assert(initialDelayMs > 0);
    assert(maxDelayMs >= initialDelayMs);
    assert(jitterFraction >= 0 && jitterFraction <= 1);

    int attemptNumber = 0;
    dynamic lastException;

    while (attemptNumber < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attemptNumber++;
        lastException = e;

        if (attemptNumber >= maxAttempts) {
          break;
        }

        // Calculate delay with exponential backoff
        final exponentialDelay =
            initialDelayMs * pow(2, attemptNumber - 1).toInt();
        final cappedDelay = min(exponentialDelay, maxDelayMs);

        // Add jitter to prevent thundering herd
        final jitter =
            (cappedDelay * jitterFraction * Random().nextDouble()).toInt();
        final finalDelay = cappedDelay + jitter;

        final duration = Duration(milliseconds: finalDelay);
        onRetry?.call(attemptNumber, duration);

        await Future.delayed(duration);
      }
    }

    throw lastException;
  }

  /// Retries an async operation without delays (useful for quick retries)
  static Future<T> retryImmediate<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Function(int attemptNumber)? onRetry,
  }) async {
    ArgumentError.checkNotNull(operation);
    assert(maxAttempts > 0);

    int attemptNumber = 0;
    dynamic lastException;

    while (attemptNumber < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attemptNumber++;
        lastException = e;

        if (attemptNumber >= maxAttempts) {
          break;
        }

        onRetry?.call(attemptNumber);
      }
    }

    throw lastException;
  }
}
