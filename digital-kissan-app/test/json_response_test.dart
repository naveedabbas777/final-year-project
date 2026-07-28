import 'package:flutter_test/flutter_test.dart';

import 'package:mockup_app/utils/json_response.dart';

void main() {
  test('asMap converts plain map-like values', () {
    final result = asMap({'a': 1, 'b': 'two'});

    expect(result, isNotNull);
    expect(result!['a'], 1);
    expect(result['b'], 'two');
  });

  test('asMapList filters invalid entries and normalizes maps', () {
    final result = asMapList([
      {'id': 1},
      'skip-me',
      {'id': 2, 'name': 'crop'},
      42,
    ]);

    expect(result, hasLength(2));
    expect(result[0]['id'], 1);
    expect(result[1]['name'], 'crop');
  });

  test('toDateTimeOrNow parses Firestore-style timestamps', () {
    final result = toDateTimeOrNow({'seconds': 1715167800});

    expect(result.millisecondsSinceEpoch, 1715167800000);
    expect(result.isUtc, isFalse);
  });

  test('toStringListOrEmpty filters blanks and coerces values', () {
    final result = toStringListOrEmpty(['hello', '', null, 42]);

    expect(result, ['hello', '42']);
  });
}
