import 'package:flutter/material.dart';

/// AI 분류 라벨(영문)을 한국어 이름으로 바꿉니다.
String koreanTrashLabel(String label) {
  switch (label.toLowerCase()) {
    case 'glass': return '유리류';
    case 'metal': return '금속류';
    case 'organics': return '음식물·유기물';
    case 'paper': return '종이류';
    case 'plastic': return '플라스틱류';
    case 'trash': return '일반쓰레기';
    default: return label;
  }
}

/// 멜버른 3색 쓰레기통(일반·재활용·음식물/유기물) 기준 배출 안내
String disposalGuide(String label) {
  switch (label.toLowerCase()) {
    case 'glass':
      return '병은 내용물을 비우고 헹군 뒤 재활용 통(노란 뚜껑)에 넣어 주세요. 깨진 유리는 일반 쓰레기로 버려 주세요.';
    case 'metal':
      return '캔은 내용물을 비우고 헹군 뒤 재활용 통(노란 뚜껑)에 넣어 주세요.';
    case 'organics':
      return '음식물·유기물은 포장재를 떼어 내고 유기물 통(초록 뚜껑)에 넣어 주세요.';
    case 'paper':
      return '종이·박스는 젖지 않게 펴서 재활용 통(노란 뚜껑)에 넣어 주세요. 기름이 묻은 종이는 일반 쓰레기예요.';
    case 'plastic':
      return '플라스틱 용기는 비우고 헹군 뒤 재활용 통(노란 뚜껑)에 넣어 주세요. 비닐류는 재활용 통에 넣지 마세요.';
    case 'trash':
      return '재활용이 어려운 쓰레기는 일반 쓰레기 통(빨간 뚜껑)에 넣어 주세요.';
    default:
      return '분리수거 방법을 확인해주세요.';
  }
}

/// 라벨로 분리수거 유형을 구합니다. (handout의 disposal_map.json과 같은 규칙)
String disposalTypeForLabel(String label) {
  switch (label.toLowerCase()) {
    case 'organics':
      return 'COMPOST';
    case 'trash':
      return 'LANDFILL';
    case 'glass':
    case 'metal':
    case 'paper':
    case 'plastic':
      return 'RECYCLING';
    default:
      return 'UNKNOWN';
  }
}

/// 분리수거 유형(COMPOST/LANDFILL/RECYCLING)에 맞는 쓰레기통 이름과 색
class BinInfo {
  final String name;
  final Color color;
  const BinInfo(this.name, this.color);
}

BinInfo binInfoFor(String disposalType) {
  switch (disposalType) {
    case 'RECYCLING':
      return const BinInfo('재활용 · 노란 뚜껑', Color(0xFFE0B000));
    case 'COMPOST':
      return const BinInfo('음식물·유기물 · 초록 뚜껑', Color(0xFF3FA34D));
    case 'LANDFILL':
      return const BinInfo('일반 쓰레기 · 빨간 뚜껑', Color(0xFFD64541));
    default:
      return const BinInfo('확인 필요', Colors.grey);
  }
}
