import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'classification_math.dart';
import 'classification_result.dart';
import 'image_preprocess.dart';

class TrashClassificationService {
  static const String _modelPath = 'handout_mobile_20250815_0505/plogging_224_fp16.tflite';
  static const String _fallbackModelPath = 'handout_mobile_20250815_0505/plogging_224_dynamic.tflite';
  static const String _labelsPath = 'handout_mobile_20250815_0505/labels.txt';
  static const String _disposalMapPath = 'handout_mobile_20250815_0505/disposal_map.json';
  static const int _inputSize = 224;

  Interpreter? _interpreter;
  List<String> _labels = [];
  Map<String, String> _disposalMap = {};
  bool _isInitialized = false;

  static final TrashClassificationService _instance = TrashClassificationService._internal();
  factory TrashClassificationService() => _instance;
  TrashClassificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
    } catch (_) {
      _interpreter = await Interpreter.fromAsset(_fallbackModelPath);
    }

    final labelsData = await rootBundle.loadString(_labelsPath);
    _labels = labelsData
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final disposalData = await rootBundle.loadString(_disposalMapPath);
    final Map<String, dynamic> parsed = jsonDecode(disposalData) as Map<String, dynamic>;
    _disposalMap = parsed.map((k, v) => MapEntry(k, v.toString()));

    _isInitialized = true;
  }

  Future<TrashClassificationResult> classifyImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    final input = preprocessForModel(imageBytes, size: _inputSize);
    final output = _runInference(input);
    return _postprocessOutput(output);
  }

  List<double> _runInference(List<List<List<double>>> input) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw Exception('인터프리터가 초기화되지 않았습니다.');
    }
    final outputSize = interpreter.getOutputTensor(0).shape.last;
    final outputTensor = [List<double>.filled(outputSize, 0.0)];
    interpreter.run([input], outputTensor);
    return outputTensor[0];
  }

  TrashClassificationResult _postprocessOutput(List<double> output) {
    final probs = toProbabilities(output);
    final results = List.generate(probs.length, (i) {
      final label = i < _labels.length ? _labels[i] : 'class_$i';
      return ClassificationResult(
        label: label,
        confidence: probs[i],
        disposalType: _disposalMap[label] ?? 'UNKNOWN',
      );
    })..sort((a, b) => b.confidence.compareTo(a.confidence));

    return TrashClassificationResult(
      topResult: results.first,
      allResults: results,
    );
  }
}
