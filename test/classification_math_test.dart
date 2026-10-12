import 'package:flogging_app/services/classification_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toProbabilities', () {
    test('모델이 이미 softmax를 적용한 출력은 그대로 사용한다', () {
      const probs = [0.895, 0.056, 0.034, 0.005, 0.005, 0.005];
      final result = toProbabilities(probs);
      expect(result, probs);
    });

    test('logits가 들어오면 softmax를 적용한다', () {
      final result = toProbabilities([2.0, 1.0, 0.1]);
      expect(result.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      expect(result[0], closeTo(0.659, 1e-3));
      expect(result[1], closeTo(0.242, 1e-3));
    });

    test('확률이 아닌 값(음수, 1 초과)은 logits로 본다', () {
      expect(looksLikeProbabilities([-1.0, 2.0]), isFalse);
      expect(looksLikeProbabilities([0.5, 0.6]), isFalse);
      expect(looksLikeProbabilities([]), isFalse);
    });
  });

  group('이전 버전 버그 재현: softmax 두 번 적용', () {
    test('6개 클래스에서 신뢰도가 최대 e/(e+5) ≈ 35.2%로 눌린다', () {
      final doubleApplied = softmax([1.0, 0, 0, 0, 0, 0]);
      expect(doubleApplied.first, closeTo(0.3522, 1e-4));
    });

    test('발표 자료의 METAL 32.4%는 실제로 약 90% 확률이었다', () {
      // 실제 확률 [0.895, 0.056, 0.034, ...]에 softmax를 한 번 더 씌우면 화면 값이 나온다.
      final shown = softmax([0.895, 0.056, 0.034, 0.005, 0.005, 0.005]);
      expect(shown[0], closeTo(0.324, 2e-3));
      expect(shown[1], closeTo(0.140, 2e-3));
      expect(shown[2], closeTo(0.137, 2e-3));
    });
  });
}
