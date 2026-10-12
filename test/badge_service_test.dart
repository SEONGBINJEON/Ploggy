import 'dart:io';
import 'package:flogging_app/models/jog_record.dart';
import 'package:flogging_app/services/badge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  group('maxConsecutiveDays', () {
    test('같은 날 여러 번 달려도 하루로 센다', () {
      final dates = [
        DateTime(2026, 9, 1, 7),
        DateTime(2026, 9, 1, 21),
        DateTime(2026, 9, 2, 8),
      ];
      expect(BadgeService.maxConsecutiveDays(dates), 2);
    });

    test('밤에 달리고 다음 날 아침에 달려도 연속으로 센다', () {
      // 시간 차이는 10시간이지만 날짜는 이어져 있다 (이전 버전은 0일로 계산했음)
      final dates = [DateTime(2026, 9, 1, 22), DateTime(2026, 9, 2, 8)];
      expect(BadgeService.maxConsecutiveDays(dates), 2);
    });

    test('하루라도 비면 연속이 끊긴다', () {
      final dates = [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 4),
        DateTime(2026, 9, 5),
        DateTime(2026, 9, 6),
      ];
      expect(BadgeService.maxConsecutiveDays(dates), 3);
      expect(BadgeService.maxConsecutiveDays([]), 0);
    });

    test('월말·연말을 넘어가도 연속으로 센다', () {
      final dates = [for (var d = 0; d < 7; d++) DateTime(2026, 12, 28).add(Duration(days: d))];
      expect(BadgeService.maxConsecutiveDays(dates), 7);
    });
  });

  group('isPerfectWeek', () {
    // 2026-09-28은 월요일
    final monday = DateTime(2026, 9, 28, 9);

    test('이번 주 월~일 모두 기록이 있으면 완벽한 한 주', () {
      final dates = [for (var d = 0; d < 7; d++) monday.add(Duration(days: d))];
      expect(BadgeService.isPerfectWeek(dates, DateTime(2026, 10, 4, 20)), isTrue);
    });

    test('하루라도 빠지거나 지난주 기록이 섞이면 아니다', () {
      final missingOne = [for (var d = 0; d < 6; d++) monday.add(Duration(days: d))];
      expect(BadgeService.isPerfectWeek(missingOne, DateTime(2026, 10, 4)), isFalse);

      final withLastSunday = [monday.subtract(const Duration(days: 1)), ...missingOne];
      expect(BadgeService.isPerfectWeek(withLastSunday, DateTime(2026, 10, 4)), isFalse);
    });
  });

  group('checkBadgeConditions (Hive 사용)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ploggy_badge_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(JogRecordAdapter());
      }
      await Hive.openBox<JogRecord>('jog_records');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Windows에서 파일 잠금이 늦게 풀리는 경우는 무시
      }
    });

    test('쓰레기 10개를 모으면 쓰레기 수집가 뱃지가 열리고, 에코 마스터도 얻을 수 있다', () async {
      await Hive.box<JogRecord>('jog_records').add(JogRecord(
        date: DateTime(2026, 9, 1, 7, 30),
        distanceKm: 5.2,
        durationSeconds: 1800,
        speedKmph: 10.4,
      ));
      final service = BadgeService();

      final first = await service.checkBadgeConditions();
      expect(first, containsAll(['first_plogging', 'distance_5km', 'morning_plogging']));
      expect(first, isNot(contains('eco_master')));

      final unlockedByTrash = <String>[];
      for (var i = 0; i < 10; i++) {
        unlockedByTrash.addAll(await service.recordTrashCollected());
      }
      expect(service.trashCount, 10);
      expect(unlockedByTrash, containsAll(['trash_10', 'eco_master']));
    });

    test('이미 얻은 뱃지는 다시 새 뱃지로 돌려주지 않는다', () async {
      await Hive.box<JogRecord>('jog_records').add(JogRecord(
        date: DateTime(2026, 9, 1, 12),
        distanceKm: 1,
        durationSeconds: 600,
        speedKmph: 6,
      ));
      final service = BadgeService();
      expect(await service.checkBadgeConditions(), contains('first_plogging'));
      expect(await service.checkBadgeConditions(), isEmpty);
    });

    test('비가 오는 날 조깅을 마치면 비 오는 날 뱃지를 준다', () async {
      final service = BadgeService();
      expect(await service.checkBadgeConditions(weatherCode: 3), isNot(contains('weather_rain')));
      expect(await service.checkBadgeConditions(weatherCode: 61), contains('weather_rain'));
      expect(await service.checkBadgeConditions(weatherCode: 73), contains('weather_snow'));
    });

    test('커뮤니티에 글을 5번 쓰면 커뮤니티 활성 뱃지를 준다', () async {
      final service = BadgeService();
      final unlocked = <String>[];
      for (var i = 0; i < 5; i++) {
        unlocked.addAll(await service.recordCommunityPost());
      }
      expect(unlocked, contains('community_share'));
    });
  });
}
