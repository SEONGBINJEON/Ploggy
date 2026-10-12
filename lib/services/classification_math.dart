import 'dart:math' as math;

/// 모델 출력이 이미 확률 분포(softmax 결과)인지 확인합니다.
///
/// 모든 값이 0~1 사이이고 합이 1에 가까우면 확률로 봅니다.
bool looksLikeProbabilities(List<double> values, {double tolerance = 1e-2}) {
  if (values.isEmpty) return false;
  var sum = 0.0;
  for (final v in values) {
    if (v.isNaN || v < 0 || v > 1) return false;
    sum += v;
  }
  return (sum - 1).abs() <= tolerance;
}

List<double> softmax(List<double> logits) {
  final maxVal = logits.reduce(math.max);
  final exps = logits.map((x) => math.exp(x - maxVal)).toList();
  final sum = exps.fold(0.0, (a, b) => a + b);
  return exps.map((x) => x / sum).toList();
}

/// 모델 출력을 확률 분포로 바꿉니다.
///
/// 현재 plogging_224_*.tflite 모델은 마지막 연산이 SOFTMAX라서 출력을 그대로 씁니다.
/// 여기에 softmax를 한 번 더 적용하면 6개 클래스 기준 신뢰도가
/// 최대 e/(e+5) ≈ 35.2%로 눌려 보입니다. (이전 버전의 버그)
List<double> toProbabilities(List<double> output) =>
    looksLikeProbabilities(output) ? List<double>.of(output) : softmax(output);
