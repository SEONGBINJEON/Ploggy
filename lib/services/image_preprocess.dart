import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 사진을 모델 입력 [size][size][3] (0~255 RGB)으로 바꿉니다.
///
/// 정규화는 모델 그래프 안에 포함돼 있어서 0~255 값을 그대로 넣습니다.
List<List<List<double>>> preprocessForModel(Uint8List imageBytes, {int size = 224}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(imageBytes);
  } catch (_) {
    // 손상되었거나 너무 짧은 파일은 decodeImage가 RangeError 등을 던집니다.
    decoded = null;
  }
  if (decoded == null) {
    throw Exception('이미지를 디코딩할 수 없습니다.');
  }
  // 카메라 사진의 EXIF 회전 정보를 반영해 눈에 보이는 방향 그대로 모델에 넣습니다.
  final oriented = img.bakeOrientation(decoded);
  final resized = img.copyResize(oriented, width: size, height: size);
  // 16비트 PNG·팔레트 이미지도 8비트 RGB로 맞춘 뒤 바이트를 읽습니다.
  final rgbBytes = resized
      .convert(format: img.Format.uint8, numChannels: 3)
      .getBytes(order: img.ChannelOrder.rgb);

  int idx = 0;
  return List.generate(size, (y) {
    return List.generate(size, (x) {
      final r = rgbBytes[idx++].toDouble();
      final g = rgbBytes[idx++].toDouble();
      final b = rgbBytes[idx++].toDouble();
      return [r, g, b];
    });
  });
}
