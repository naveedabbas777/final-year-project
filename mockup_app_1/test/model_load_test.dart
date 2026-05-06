import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  test('model assets are readable', () async {
    final model = File('assets/model/model.tflite');
    final labels = File('assets/model/labels.txt');

    expect(await model.exists(), isTrue, reason: 'model.tflite should exist');
    expect(await labels.exists(), isTrue, reason: 'labels.txt should exist');

    final modelLength = await model.length();
    expect(
      modelLength,
      greaterThan(1024),
      reason: 'model file should not be empty',
    );

    final labelLines = await labels.readAsLines();
    expect(labelLines, isNotEmpty, reason: 'labels file should not be empty');
    expect(
      labelLines.length,
      39,
      reason: 'expected 39 labels including background',
    );
    expect(labelLines.last.trim().toLowerCase(), 'background');
  });
}
