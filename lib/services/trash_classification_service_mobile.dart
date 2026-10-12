import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TrashClassificationService {
  static const String _modelPath = 'handout_mobile_20250815_0505/plogging_224_fp16.tflite';
  static const String _fallbackModelPath = 'handout_mobile_20250815_0505/plogging_224_dynamic.tflite';
  static const String _labelsPath = 'handout_mobile_20250815_0505/labels.txt';
  static const String _disposalMapPath = 'handout_mobile_20250815_0505/disposal_map.json';

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
    } catch (e) {
      rethrow;
    }
  }

  Future<TrashClassificationResult> classifyImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    final input = _preprocessImageBytes(imageBytes);
    final output = await _runInference(input);
    return _postprocessOutput(output);
  }

  List<List<List<double>>> _preprocessImageBytes(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('이미지를 디코딩할 수 없습니다.');
    }
    final resized = img.copyResize(decoded, width: 224, height: 224);
    final rgbBytes = resized.getBytes(order: img.ChannelOrder.rgb);

    int idx = 0;
    final input = List.generate(224, (y) {
      return List.generate(224, (x) {
        final r = rgbBytes[idx++].toDouble();
        final g = rgbBytes[idx++].toDouble();
        final b = rgbBytes[idx++].toDouble();
        return [r, g, b];
      });
    });
    return input;
  }

  Future<List<double>> _runInference(List<List<List<double>>> input) async {
    if (_interpreter == null) {
      throw Exception('인터프리터가 초기화되지 않았습니다.');
    }
    final inputTensor = [input];
    final outputTensor = List.generate(1, (_) => List.filled(6, 0.0));
    _interpreter!.run(inputTensor, outputTensor);
    return outputTensor[0];
  }

  TrashClassificationResult _postprocessOutput(List<double> logits) {
    final probs = _softmax(logits);
    final results = List.generate(probs.length, (i) {
      final label = _labels[i];
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

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(math.max);
    final exps = logits.map((x) => math.exp(x - maxVal)).toList();
    final sum = exps.fold(0.0, (a, b) => a + b);
    return exps.map((x) => x / (sum == 0 ? 1 : sum)).toList();
  }
}

class ClassificationResult {
  final String label;
  final double confidence;
  final String disposalType;
  ClassificationResult({required this.label, required this.confidence, required this.disposalType});
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}

class TrashClassificationResult {
  final ClassificationResult topResult;
  final List<ClassificationResult> allResults;
  TrashClassificationResult({required this.topResult, required this.allResults});
}


