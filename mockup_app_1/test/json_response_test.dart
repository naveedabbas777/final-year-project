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
}
