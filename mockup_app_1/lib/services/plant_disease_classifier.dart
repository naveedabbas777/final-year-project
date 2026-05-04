import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
// import 'package:tflite_flutter/tflite_flutter.dart';
// NOTE: tflite_flutter requires Git. Commented out to avoid git dependency.
// To re-enable: Install Git from https://git-scm.com/download/win
// Then uncomment this line and add "tflite_flutter: ^0.12.1" to pubspec.yaml

class Prediction {
  Prediction({required this.label, required this.score});
  final String label;
  final double score;
}

// Plant Disease Classifier is disabled due to tflite_flutter git dependency
// To enable: Install Git and uncomment tflite_flutter import above, then uncomment the class below

/*
class PlantDiseaseClassifier {
  PlantDiseaseClassifier._(this._interpreter, this.labels)
      : inputShape = _interpreter.getInputTensor(0).shape,
        outputShape = _interpreter.getOutputTensor(0).shape,
        inputType = _interpreter.getInputTensor(0).type,
        outputType = _interpreter.getOutputTensor(0).type;

  final Interpreter _interpreter;
  final List<String> labels;
  final List<int> inputShape;
  final List<int> outputShape;
  final TensorType inputType;
  final TensorType outputType;

  static Future<PlantDiseaseClassifier> load() async {
    final interpreter = await Interpreter.fromAsset('assets/model/model.tflite');
    final raw = await rootBundle.loadString('assets/model/labels.txt');
    final labels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return PlantDiseaseClassifier._(interpreter, labels);
  }

  Future<List<Prediction>> classify(Uint8List imageBytes, {int topK = 3}) async {
    final img.Image? original = img.decodeImage(imageBytes);
    if (original == null) {
      throw ArgumentError('Unable to decode image bytes');
    }

    if (inputShape.length != 4 || inputShape[0] != 1) {
      throw StateError('Unexpected input shape: $inputShape');
    }
    final height = inputShape[1];
    final width = inputShape[2];

    final resized = img.copyResize(original, width: width, height: height);

    final input = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;
          return [r, g, b];
        },
      ),
    );

    final output = List.generate(1, (_) => List.filled(labels.length, 0.0));

    _interpreter.run([input], output);

    final scores = output.first;
    final predictions = <Prediction>[];
    for (var i = 0; i < scores.length && i < labels.length; i++) {
      predictions.add(Prediction(label: labels[i], score: scores[i].toDouble()));
    }

    predictions.sort((a, b) => b.score.compareTo(a.score));
    return predictions.take(topK).toList();
  }

  void dispose() {
    _interpreter.close();
  }
}
*/
