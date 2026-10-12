import 'dart:typed_data';
import 'package:flogging_app/services/image_preprocess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// 왼쪽 절반은 빨강, 오른쪽 절반은 파랑인 테스트 이미지
img.Image _halfRedHalfBlue({int width = 64, int height = 32, int numChannels = 3, img.Format format = img.Format.uint8}) {
  final image = img.Image(width: width, height: height, numChannels: numChannels, format: format);
  final max = format == img.Format.uint16 ? 65535 : 255;
  for (final p in image) {
    if (p.x < width ~/ 2) {
      p
        ..r = max
        ..g = 0
        ..b = 0;
    } else {
      p
        ..r = 0
        ..g = 0
        ..b = max;
    }
    if (numChannels == 4) p.a = max;
  }
  return image;
}

bool _isRed(List<double> rgb) => rgb[0] > 200 && rgb[2] < 60;
bool _isBlue(List<double> rgb) => rgb[2] > 200 && rgb[0] < 60;

void main() {
  test('출력은 224x224x3, 값은 0~255 범위 그대로다', () {
    final bytes = Uint8List.fromList(img.encodePng(_halfRedHalfBlue()));
    final input = preprocessForModel(bytes);
    expect(input, hasLength(224));
    expect(input.first, hasLength(224));
    expect(input.first.first, hasLength(3));
    expect(_isRed(input[112][20]), isTrue);
    expect(_isBlue(input[112][200]), isTrue);
  });

  test('EXIF 회전 정보(orientation=6)를 반영해 세운 방향으로 넣는다', () {
    final image = _halfRedHalfBlue();
    // orientation 6 = 시계 방향 90도 회전해서 봐야 하는 사진 (세로로 찍은 폰 사진에 흔함)
    image.exif.imageIfd.orientation = 6;
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 95));

    final input = preprocessForModel(bytes);
    // 90도 돌리면 왼쪽(빨강)이 위로 간다 → 위쪽은 가로 전체가 빨강
    expect(_isRed(input[20][40]), isTrue);
    expect(_isRed(input[20][180]), isTrue);
    expect(_isBlue(input[200][40]), isTrue);
    expect(_isBlue(input[200][180]), isTrue);
  });

  test('16비트·알파 채널 PNG도 8비트 RGB로 바꿔서 넣는다', () {
    final image = _halfRedHalfBlue(numChannels: 4, format: img.Format.uint16);
    final bytes = Uint8List.fromList(img.encodePng(image));
    final input = preprocessForModel(bytes);
    expect(input.first.first, hasLength(3));
    expect(_isRed(input[112][20]), isTrue);
    expect(_isBlue(input[112][200]), isTrue);
    for (final value in input[112][20]) {
      expect(value, inInclusiveRange(0, 255));
    }
  });

  test('이미지가 아니면 알기 쉬운 오류를 낸다', () {
    expect(() => preprocessForModel(Uint8List.fromList([1, 2, 3])), throwsException);
  });
}
