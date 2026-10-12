import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flogging_app/models/community_post.dart';
import 'package:flogging_app/models/diary_entry.dart';
import 'package:flogging_app/models/user.dart';
import 'package:flogging_app/utils/trash_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PloggingUser', () {
    test('정수·실수로 저장된 누적 기록을 모두 읽는다', () {
      final oldUser = PloggingUser.fromMap({'id': 'a', 'name': '성빈', 'totalDistance': 0, 'totalTrash': 3, 'badges': []});
      expect(oldUser.totalDistance, 0.0);
      expect(oldUser.totalTrash, 3);

      final user = PloggingUser.fromMap({'name': '플로거', 'totalDistance': 12.34, 'totalDurationSec': 3600}, id: 'b');
      expect(user.id, 'b');
      expect(user.totalDistance, 12.34);
      expect(user.totalDurationSec, 3600);
      expect(user.badges, isEmpty);
    });

    test('이름이 없으면 기본 이름을 쓰고, 이메일은 저장하지 않는다', () {
      expect(PloggingUser.fromMap({}, id: 'c').name, '이름 없는 플로거');
      expect(const PloggingUser(id: 'd', name: '플로거').toMap().containsKey('email'), isFalse);
    });
  });

  test('DiaryEntry는 이전 버전처럼 문자열로 저장된 거리·스텝도 읽는다', () {
    final entry = DiaryEntry.fromMap('id1', {
      'title': '야라강 플로깅',
      'distance': '3.5',
      'steps': '4200',
      'time': '40m',
      'memo': '캔 5개',
      'createdAt': Timestamp.fromDate(DateTime(2025, 9, 10, 8)),
    });
    expect(entry.distanceKm, 3.5);
    expect(entry.steps, 4200);
    expect(entry.userId, '');
    expect(entry.createdAt, DateTime(2025, 9, 10, 8));
  });

  test('CommunityPost는 저장 직후(서버 시간 없음)에도 읽힌다', () {
    final post = CommunityPost.fromMap('p1', {'title': '첫 글', 'content': '안녕하세요', 'createdAt': null});
    expect(post.authorName, '플로거');
    expect(post.imageUrl, '');
    expect(DateTime.now().difference(post.createdAt).inSeconds, lessThan(5));
  });

  test('분리수거 유형은 handout의 disposal_map.json 규칙과 같다', () {
    final disposalMap = jsonDecode(
      File('handout_mobile_20250815_0505/disposal_map.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final labels = File('handout_mobile_20250815_0505/labels.txt')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);

    for (final label in labels) {
      expect(disposalTypeForLabel(label), disposalMap[label], reason: label);
      expect(koreanTrashLabel(label), isNot(label), reason: '$label의 한국어 이름');
    }
    expect(binInfoFor('RECYCLING').name, contains('노란 뚜껑'));
  });
}
