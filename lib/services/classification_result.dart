class ClassificationResult {
  final String label;
  final double confidence;
  final String disposalType;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.disposalType,
  });

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}

class TrashClassificationResult {
  final ClassificationResult topResult;
  final List<ClassificationResult> allResults;

  /// 웹처럼 실제 모델을 돌릴 수 없는 환경에서 만든 예시 결과인지 여부
  final bool isDemo;

  const TrashClassificationResult({
    required this.topResult,
    required this.allResults,
    this.isDemo = false,
  });
}
