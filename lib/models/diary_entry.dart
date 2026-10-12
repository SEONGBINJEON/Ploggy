import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `plogging_diary` 문서
class DiaryEntry {
  final String id;
  final String userId;
  final String title;
  final double? distanceKm;
  final String time;
  final int? steps;
  final String memo;
  final String imageUrl;
  final DateTime createdAt;

  const DiaryEntry({
    this.id = '',
    required this.userId,
    required this.title,
    this.distanceKm,
    this.time = '',
    this.steps,
    this.memo = '',
    this.imageUrl = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'distance': distanceKm,
    'time': time,
    'steps': steps,
    'memo': memo,
    'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };

  // 이전 버전은 거리·스텝을 문자열로 저장했기 때문에 숫자/문자열 모두 읽습니다.
  factory DiaryEntry.fromMap(String id, Map<String, dynamic> map) => DiaryEntry(
    id: id,
    userId: map['userId'] as String? ?? '',
    title: map['title'] as String? ?? '',
    distanceKm: _toDouble(map['distance']),
    time: map['time']?.toString() ?? '',
    steps: _toDouble(map['steps'])?.round(),
    memo: map['memo'] as String? ?? '',
    imageUrl: map['imageUrl'] as String? ?? '',
    createdAt: _toDate(map['createdAt']),
  );

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  // 저장 직후 서버 시간이 아직 없으면(null) 현재 시각으로 표시합니다.
  static DateTime _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
