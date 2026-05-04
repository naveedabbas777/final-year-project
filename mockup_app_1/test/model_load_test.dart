import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

dynamic _zerosForShape(List<int> shape, Object fill) {
  if (shape.isEmpty) return fill;
  final head = shape.first;
  final tail = shape.sublist(1);
  return List.generate(head, (_) => _zerosForShape(tail, fill));
}

List<double> _flattenToDouble(dynamic value) {
  if (value is num) return [value.toDouble()];
  if (value is List) {
    return value.expand((e) => _flattenToDouble(e)).toList();
  }
  return const [];
}

Object _zeroValueForType(TensorType type) {
  switch (type) {
    case TensorType.float32:
    case TensorType.float64:
      return 0.0;
    default:
      return 0;
  }
}

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

  test(
    'tflite interpreter loads and runs',
    () async {
    final buffer = await File('assets/model/model.tflite').readAsBytes();
    final interpreter = await Interpreter.fromBuffer(buffer);
    addTearDown(interpreter.close);

    interpreter.allocateTensors();

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    final input = _zerosForShape(
      inputTensor.shape,
      _zeroValueForType(inputTensor.type),
    );
    final output = _zerosForShape(
      outputTensor.shape,
      _zeroValueForType(outputTensor.type),
    );

    interpreter.run(input, output);

    final flatOutput = _flattenToDouble(output);
    expect(flatOutput, isNotEmpty, reason: 'interpreter should produce output');
    expect(
      flatOutput.every((v) => v.isFinite),
      isTrue,
      reason: 'output values should be finite',
    );

    final labels = await File('assets/model/labels.txt').readAsLines();
    expect(
      outputTensor.shape.last,
      labels.length,
      reason: 'output dimension should match label count',
    );
    },
    skip: Platform.isWindows
        ? 'TFLite native DLL missing on Windows; provide libtensorflowlite_c-win.dll to run'
        : false,
  );
}
