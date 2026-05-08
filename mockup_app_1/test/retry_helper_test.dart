import 'package:flutter_test/flutter_test.dart';
import 'package:mockup_app/utils/retry_helper.dart';

void main() {
  test('retryImmediate retries until the operation succeeds', () async {
    var attempts = 0;

    final result = await RetryHelper.retryImmediate<String>(
      () async {
        attempts += 1;
        if (attempts < 3) {
          throw Exception('temporary failure');
        }
        return 'ok';
      },
      maxAttempts: 3,
    );

    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('retry reports retry attempts before the final success', () async {
    final retryAttempts = <int>[];
    var attempts = 0;

    final result = await RetryHelper.retry<String>(
      () async {
        attempts += 1;
        if (attempts < 2) {
          throw Exception('temporary failure');
        }
        return 'done';
      },
      maxAttempts: 2,
      initialDelayMs: 1,
      maxDelayMs: 1,
      jitterFraction: 0,
      onRetry: (attemptNumber, _) => retryAttempts.add(attemptNumber),
    );

    expect(result, 'done');
    expect(retryAttempts, [1]);
  });
}
