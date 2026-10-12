import 'dart:math' as math;
import 'dart:typed_data';

class TrashClassificationService {
  List<String> _labels = ['glass', 'metal', 'organics', 'paper', 'plastic', 'trash'];
  final Map<String, String> _disposalMap = const {
    'organics': 'COMPOST',
    'trash': 'LANDFILL',
    'glass': 'RECYCLING',
    'metal': 'RECYCLING',
    'paper': 'RECYCLING',
    'plastic': 'RECYCLING',
  };
  bool _isInitialized = false;

  static final TrashClassificationService _instance = TrashClassificationService._internal();
  factory TrashClassificationService() => _instance;
  TrashClassificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  Future<TrashClassificationResult> classifyImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }
    final rnd = math.Random();
    final label = _labels[rnd.nextInt(_labels.length)];
    final confidence = 0.7 + rnd.nextDouble() * 0.25;
    final all = _labels
        .map((l) => ClassificationResult(
              label: l,
              confidence: rnd.nextDouble(),
              disposalType: _disposalMap[l] ?? 'UNKNOWN',
            ))
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return TrashClassificationResult(
      topResult: ClassificationResult(
        label: label,
        confidence: confidence,
        disposalType: _disposalMap[label] ?? 'UNKNOWN',
      ),
      allResults: all,
    );
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


