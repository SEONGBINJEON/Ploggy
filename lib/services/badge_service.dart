import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/jog_record.dart';
import 'weather_service.dart';

class BadgeService extends ChangeNotifier {
  static const String _badgeBoxName = 'user_badges';
  static const String _statsBoxName = 'user_stats';
  static const String _trashCountKey = 'trash_count';
  static const String _postCountKey = 'post_count';

  // 뱃지 데이터
  static const List<Map<String, dynamic>> _badges = [
    {
      'id': 'first_plogging',
      'title': '첫 플로깅',
      'description': '첫 번째 플로깅 완료',
      'icon': Icons.eco,
      'color': Colors.green,
    },
    {
      'id': 'distance_5km',
      'title': '5km 달성',
      'description': '총 5km 플로깅 완료',
      'icon': Icons.directions_run,
      'color': Colors.blue,
    },
    {
      'id': 'distance_10km',
      'title': '10km 달성',
      'description': '총 10km 플로깅 완료',
      'icon': Icons.directions_run,
      'color': Colors.purple,
    },
    {
      'id': 'distance_50km',
      'title': '50km 달성',
      'description': '총 50km 플로깅 완료',
      'icon': Icons.directions_run,
      'color': Colors.orange,
    },
    {
      'id': 'trash_10',
      'title': '쓰레기 수집가',
      'description': '10개의 쓰레기 수집',
      'icon': Icons.delete,
      'color': Colors.red,
    },
    {
      'id': 'trash_50',
      'title': '환경 보호자',
      'description': '50개의 쓰레기 수집',
      'icon': Icons.delete_sweep,
      'color': Colors.teal,
    },
    {
      'id': 'trash_100',
      'title': '지구의 친구',
      'description': '100개의 쓰레기 수집',
      'icon': Icons.cleaning_services,
      'color': Colors.indigo,
    },
    {
      'id': 'streak_7',
      'title': '일주일 연속',
      'description': '7일 연속 플로깅',
      'icon': Icons.local_fire_department,
      'color': Colors.deepOrange,
    },
    {
      'id': 'streak_30',
      'title': '한 달 연속',
      'description': '30일 연속 플로깅',
      'icon': Icons.local_fire_department,
      'color': Colors.red,
    },
    {
      'id': 'morning_plogging',
      'title': '아침 플로거',
      'description': '아침 6-9시 플로깅',
      'icon': Icons.wb_sunny,
      'color': Colors.amber,
    },
    {
      'id': 'night_plogging',
      'title': '밤 플로거',
      'description': '밤 9-12시 플로깅',
      'icon': Icons.nightlight,
      'color': Colors.indigo,
    },
    {
      'id': 'weather_rain',
      'title': '비 오는 날',
      'description': '비 오는 날 플로깅',
      'icon': Icons.water_drop,
      'color': Colors.blue,
    },
    {
      'id': 'weather_snow',
      'title': '눈 오는 날',
      'description': '눈 오는 날 플로깅',
      'icon': Icons.ac_unit,
      'color': Colors.lightBlue,
    },
    {
      'id': 'community_share',
      'title': '커뮤니티 활성',
      'description': '커뮤니티에 5번 글 작성',
      'icon': Icons.people,
      'color': Colors.pink,
    },
    {
      'id': 'perfect_week',
      'title': '완벽한 한 주',
      'description': '한 주 동안 매일 플로깅',
      'icon': Icons.star,
      'color': Colors.yellow,
    },
    {
      'id': 'eco_master',
      'title': '에코 마스터',
      'description': '모든 기본 뱃지 획득',
      'icon': Icons.emoji_events,
      'color': Colors.amber,
    },
  ];

  // 에코 마스터 조건이 되는 기본 뱃지
  static const List<String> _basicBadges = [
    'first_plogging', 'distance_5km', 'trash_10', 'morning_plogging',
  ];

  // 획득한 뱃지 목록
  Set<String> _unlockedBadges = {};

  // 새로 획득한 뱃지 (팝업 표시용)
  String? _newlyUnlockedBadge;

  bool _isInitialized = false;

  // Getters
  List<Map<String, dynamic>> get badges => _badges;
  Set<String> get unlockedBadges => _unlockedBadges;
  String? get newlyUnlockedBadge => _newlyUnlockedBadge;

  Box get _statsBox => Hive.box(_statsBoxName);
  int get trashCount => _statsBox.get(_trashCountKey, defaultValue: 0) as int;
  int get postCount => _statsBox.get(_postCountKey, defaultValue: 0) as int;

  // 뱃지 초기화 (여러 번 불러도 한 번만 실행)
  Future<void> initialize() async {
    if (_isInitialized) return;
    final box = await Hive.openBox<String>(_badgeBoxName);
    await Hive.openBox(_statsBoxName);
    _unlockedBadges = box.values.toSet();
    _isInitialized = true;
    notifyListeners();
  }

  // 뱃지 획득 여부 확인
  bool isUnlocked(String badgeId) {
    return _unlockedBadges.contains(badgeId);
  }

  // 뱃지 획득
  Future<void> unlockBadge(String badgeId) async {
    if (!_unlockedBadges.contains(badgeId)) {
      _unlockedBadges.add(badgeId);
      _newlyUnlockedBadge = badgeId;

      // Hive에 저장
      final box = await Hive.openBox<String>(_badgeBoxName);
      await box.put(badgeId, badgeId);

      notifyListeners();
    }
  }

  // 새로 획득한 뱃지 팝업 표시 후 초기화
  void clearNewlyUnlockedBadge() {
    _newlyUnlockedBadge = null;
    notifyListeners();
  }

  /// 쓰레기 기록을 저장했을 때 호출합니다. 새로 얻은 뱃지 id를 돌려줍니다.
  Future<List<String>> recordTrashCollected() async {
    await initialize();
    await _statsBox.put(_trashCountKey, trashCount + 1);
    return checkBadgeConditions();
  }

  /// 커뮤니티에 글을 올렸을 때 호출합니다. 새로 얻은 뱃지 id를 돌려줍니다.
  Future<List<String>> recordCommunityPost() async {
    await initialize();
    await _statsBox.put(_postCountKey, postCount + 1);
    return checkBadgeConditions();
  }

  /// 뱃지 획득 조건 체크
  ///
  /// [weatherCode]는 조깅을 마친 시점의 WMO 날씨 코드입니다. (비/눈 뱃지용)
  Future<List<String>> checkBadgeConditions({int? weatherCode}) async {
    await initialize();
    final newlyUnlocked = <String>[];

    Future<void> unlockIf(bool condition, String badgeId) async {
      if (condition && !isUnlocked(badgeId)) {
        await unlockBadge(badgeId);
        newlyUnlocked.add(badgeId);
      }
    }

    try {
      final records = Hive.box<JogRecord>('jog_records').values.toList();
      final dates = records.map((r) => r.date).toList();
      final totalDistance = records.fold<double>(0, (sum, record) => sum + record.distanceKm);
      final streak = maxConsecutiveDays(dates);

      // 조깅 기록 기반 뱃지
      await unlockIf(records.isNotEmpty, 'first_plogging');
      await unlockIf(totalDistance >= 5, 'distance_5km');
      await unlockIf(totalDistance >= 10, 'distance_10km');
      await unlockIf(totalDistance >= 50, 'distance_50km');
      await unlockIf(dates.any((d) => d.hour >= 6 && d.hour < 9), 'morning_plogging');
      await unlockIf(dates.any((d) => d.hour >= 21), 'night_plogging');
      await unlockIf(streak >= 7, 'streak_7');
      await unlockIf(streak >= 30, 'streak_30');
      await unlockIf(isPerfectWeek(dates, DateTime.now()), 'perfect_week');

      // 쓰레기 수거·커뮤니티 뱃지
      await unlockIf(trashCount >= 10, 'trash_10');
      await unlockIf(trashCount >= 50, 'trash_50');
      await unlockIf(trashCount >= 100, 'trash_100');
      await unlockIf(postCount >= 5, 'community_share');

      // 날씨 뱃지
      final weather = WeatherService.conditionFromCode(weatherCode);
      await unlockIf(weather == WeatherCondition.rain, 'weather_rain');
      await unlockIf(weather == WeatherCondition.snow, 'weather_snow');

      // 에코 마스터 뱃지 (기본 뱃지들 모두 획득 시)
      await unlockIf(_basicBadges.every(isUnlocked), 'eco_master');
    } catch (e) {
      debugPrint('뱃지 조건 체크 오류: $e');
    }

    return newlyUnlocked;
  }

  /// 서로 다른 날짜 기준으로 가장 긴 연속 일수를 셉니다. (같은 날 여러 번은 하루로 계산)
  static int maxConsecutiveDays(Iterable<DateTime> dates) {
    final days = dates.map(_dayOf).toSet().toList()..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  /// [now]가 속한 주(월~일)의 7일 모두 기록이 있는지 확인합니다.
  static bool isPerfectWeek(Iterable<DateTime> dates, DateTime now) {
    final monday = _dayOf(now).subtract(Duration(days: now.weekday - 1));
    final daysThisWeek = dates
        .map(_dayOf)
        .where((d) => !d.isBefore(monday) && d.difference(monday).inDays < 7)
        .toSet();
    return daysThisWeek.length == 7;
  }

  // 시간대·서머타임 영향 없이 날짜만 비교하려고 UTC 자정으로 맞춥니다.
  static DateTime _dayOf(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  // 뱃지 데이터에 획득 상태 추가
  List<Map<String, dynamic>> getBadgesWithStatus() {
    return _badges.map((badge) => {
      ...badge,
      'isUnlocked': isUnlocked(badge['id']),
    }).toList();
  }
}
