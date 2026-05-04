import 'dart:typed_data';

import 'package:flutter/foundation.dart';
// import 'package:mockup_app/services/plant_disease_classifier.dart';
// NOTE: PlantDiseaseClassifier requires tflite_flutter (Git dependency)
// Disabled to avoid git requirement. To re-enable:
// 1. Install Git from https://git-scm.com/download/win
// 2. Uncomment the import above
// 3. Uncomment the classifyBytes method below
// 4. Add "tflite_flutter: ^0.12.1" to pubspec.yaml

class PlantDiseaseProvider extends ChangeNotifier {
  // PlantDiseaseClassifier? _classifier;
  bool _isLoading = false;
  String? _error = 'Plant disease detection is disabled (requires Git for tflite_flutter)';
  // List<Prediction> _predictions = const [];
  List<dynamic> _predictions = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<dynamic> get predictions => _predictions;

  /*
  Future<void> _ensureLoaded() async {
    _classifier ??= await PlantDiseaseClassifier.load();
  }

  Future<void> classifyBytes(Uint8List bytes) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _ensureLoaded();
      final result = await _classifier!.classify(bytes);
      _predictions = result;
    } catch (e) {
      _error = e.toString();
      _predictions = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  */

  Future<void> classifyBytes(Uint8List bytes) async {
    // Disabled - requires tflite_flutter with Git
    _error = 'Plant disease detection is disabled (requires Git for tflite_flutter)';
    notifyListeners();
  }

  @override
  void dispose() {
    // _classifier?.dispose();
    super.dispose();
  }
}
