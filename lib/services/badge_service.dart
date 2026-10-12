import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/jog_record.dart';

class BadgeService extends ChangeNotifier {
  static const String _badgeBoxName = 'user_badges';
  
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

  // 획득한 뱃지 목록
  Set<String> _unlockedBadges = {};

  // 새로 획득한 뱃지 (팝업 표시용)
  String? _newlyUnlockedBadge;

  // Getters
  List<Map<String, dynamic>> get badges => _badges;
  Set<String> get unlockedBadges => _unlockedBadges;
  String? get newlyUnlockedBadge => _newlyUnlockedBadge;

  // 뱃지 초기화
  Future<void> initialize() async {
    final box = await Hive.openBox<String>(_badgeBoxName);
    _unlockedBadges = box.values.toSet();
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

  // 뱃지 획득 조건 체크
  Future<List<String>> checkBadgeConditions() async {
    final newlyUnlocked = <String>[];
    
    try {
      final jogBox = Hive.box<JogRecord>('jog_records');
      final records = jogBox.values.toList();
      
      if (records.isEmpty) return newlyUnlocked;

      // 첫 플로깅 뱃지
      if (!isUnlocked('first_plogging')) {
        await unlockBadge('first_plogging');
        newlyUnlocked.add('first_plogging');
      }

      // 거리 뱃지들
      final totalDistance = records.fold<double>(0, (sum, record) => sum + record.distanceKm);
      
      if (totalDistance >= 5 && !isUnlocked('distance_5km')) {
        await unlockBadge('distance_5km');
        newlyUnlocked.add('distance_5km');
      }
      
      if (totalDistance >= 10 && !isUnlocked('distance_10km')) {
        await unlockBadge('distance_10km');
        newlyUnlocked.add('distance_10km');
      }
      
      if (totalDistance >= 50 && !isUnlocked('distance_50km')) {
        await unlockBadge('distance_50km');
        newlyUnlocked.add('distance_50km');
      }

      // 시간대 뱃지들
      for (final record in records) {
        final hour = record.date.hour;
        
        if (hour >= 6 && hour < 9 && !isUnlocked('morning_plogging')) {
          await unlockBadge('morning_plogging');
          newlyUnlocked.add('morning_plogging');
        }
        
        if (hour >= 21 && hour < 24 && !isUnlocked('night_plogging')) {
          await unlockBadge('night_plogging');
          newlyUnlocked.add('night_plogging');
        }
      }

      // 연속 플로깅 뱃지들
      final sortedRecords = records..sort((a, b) => a.date.compareTo(b.date));
      int currentStreak = 1;
      int maxStreak = 1;
      
      for (int i = 1; i < sortedRecords.length; i++) {
        final prevDate = sortedRecords[i - 1].date;
        final currDate = sortedRecords[i].date;
        final daysDiff = currDate.difference(prevDate).inDays;
        
        if (daysDiff == 1) {
          currentStreak++;
          maxStreak = maxStreak < currentStreak ? currentStreak : maxStreak;
        } else if (daysDiff > 1) {
          currentStreak = 1;
        }
      }
      
      if (maxStreak >= 7 && !isUnlocked('streak_7')) {
        await unlockBadge('streak_7');
        newlyUnlocked.add('streak_7');
      }
      
      if (maxStreak >= 30 && !isUnlocked('streak_30')) {
        await unlockBadge('streak_30');
        newlyUnlocked.add('streak_30');
      }

      // 완벽한 한 주 뱃지
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weekRecords = records.where((record) => 
        record.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        record.date.isBefore(weekEnd.add(const Duration(days: 1)))
      ).toList();
      
      final weekDays = weekRecords.map((r) => r.date.weekday).toSet();
      if (weekDays.length >= 7 && !isUnlocked('perfect_week')) {
        await unlockBadge('perfect_week');
        newlyUnlocked.add('perfect_week');
      }

      // 에코 마스터 뱃지 (기본 뱃지들 모두 획득 시)
      final basicBadges = [
        'first_plogging', 'distance_5km', 'trash_10', 'morning_plogging'
      ];
      
      if (basicBadges.every((badge) => isUnlocked(badge)) && !isUnlocked('eco_master')) {
        await unlockBadge('eco_master');
        newlyUnlocked.add('eco_master');
      }

    } catch (e) {
      print('뱃지 조건 체크 오류: $e');
    }

    return newlyUnlocked;
  }

  // 뱃지 데이터에 획득 상태 추가
  List<Map<String, dynamic>> getBadgesWithStatus() {
    return _badges.map((badge) => {
      ...badge,
      'isUnlocked': isUnlocked(badge['id']),
    }).toList();
  }
} 