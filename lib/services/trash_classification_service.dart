// 이 파일은 플랫폼 프록시입니다. 웹/모바일 구현을 조건부 임포트합니다.
import 'dart:typed_data';
import 'classification_result.dart';
import 'trash_classification_service_mobile.dart'
    if (dart.library.js_interop) 'trash_classification_service_web.dart' as impl;

export 'classification_result.dart';

// 통합 인터페이스. 실제 구현은 조건부 임포트된 impl을 위임해 사용합니다.
class TrashClassificationService {
  final impl.TrashClassificationService _delegate = impl.TrashClassificationService();
  Future<void> initialize() => _delegate.initialize();
  Future<TrashClassificationResult> classifyImage(Uint8List imageBytes) =>
      _delegate.classifyImage(imageBytes);
}
