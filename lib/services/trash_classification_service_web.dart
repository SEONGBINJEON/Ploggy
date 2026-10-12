import 'dart:math' as math;
import 'dart:typed_data';
import 'classification_result.dart';

/// 웹에서는 tflite_flutter가 동작하지 않으므로, 화면 흐름 확인용 예시 결과를 돌려줍니다.
/// 결과에 isDemo가 표시되어 화면에서 실제 AI 결과가 아니라는 안내를 보여줍니다.
class TrashClassificationService {
  static const List<String> _labels = ['glass', 'metal', 'organics', 'paper', 'plastic', 'trash'];
  static const Map<String, String> _disposalMap = {
    'organics': 'COMPOST',
    'trash': 'LANDFILL',
    'glass': 'RECYCLING',
    'metal': 'RECYCLING',
    'paper': 'RECYCLING',
    'plastic': 'RECYCLING',
  };
  final math.Random _random = math.Random();

  static final TrashClassificationService _instance = TrashClassificationService._internal();
  factory TrashClassificationService() => _instance;
  TrashClassificationService._internal();

  Future<void> initialize() async {}

  Future<TrashClassificationResult> classifyImage(Uint8List imageBytes) async {
    final raw = List.generate(_labels.length, (_) => _random.nextDouble());
    final sum = raw.fold(0.0, (a, b) => a + b);
    final results = List.generate(_labels.length, (i) {
      return ClassificationResult(
        label: _labels[i],
        confidence: raw[i] / sum,
        disposalType: _disposalMap[_labels[i]] ?? 'UNKNOWN',
      );
    })..sort((a, b) => b.confidence.compareTo(a.confidence));

    return TrashClassificationResult(
      topResult: results.first,
      allResults: results,
      isDemo: true,
    );
  }
}
