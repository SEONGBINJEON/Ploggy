class AIService {
  // 예시: 이미지 경로를 받아 쓰레기 종류를 반환
  Future<String> classifyTrash(String imagePath) async {
    // TODO: Firebase ML Kit 또는 외부 AI API 연동
    // 임시로 랜덤 분류
    List<String> types = ['플라스틱', '종이', '캔', '유리', '일반쓰레기'];
    types.shuffle();
    return types.first;
  }
} 