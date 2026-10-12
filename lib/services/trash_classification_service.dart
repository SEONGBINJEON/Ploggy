// 이 파일은 플랫폼 프록시입니다. 웹/모바일 구현을 조건부 임포트합니다.
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'trash_classification_service_mobile.dart'
    if (dart.library.html) 'trash_classification_service_web.dart' as impl;

// 통합 인터페이스. 실제 구현은 조건부 임포트된 impl을 위임해 사용합니다.
class TrashClassificationService {
  final impl.TrashClassificationService _delegate = impl.TrashClassificationService();
  Future<void> initialize() => _delegate.initialize();
  Future<impl.TrashClassificationResult> classifyImage(Uint8List imageBytes) => _delegate.classifyImage(imageBytes);
}

typedef ClassificationResult = impl.ClassificationResult;
typedef TrashClassificationResult = impl.TrashClassificationResult;
