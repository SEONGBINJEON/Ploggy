import 'package:flutter/foundation.dart';

/// 하단 탭 인덱스. 홈 화면의 바로가기 버튼에서도 탭을 바꿀 때 사용합니다.
/// 0: 홈, 1: 다이어리, 2: 쓰레기 분류, 3: 조깅, 4: 커뮤니티
final ValueNotifier<int> tabIndexNotifier = ValueNotifier<int>(0);
