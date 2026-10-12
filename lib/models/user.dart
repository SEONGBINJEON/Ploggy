/// Firestore `users/{uid}`(본인 전용 프로필)와 `leaderboard/{uid}`(랭킹용 공개 기록) 문서.
/// 이메일은 Firebase Auth에만 두고 Firestore에는 저장하지 않습니다.
class PloggingUser {
  final String id;
  final String name;
  final String profileImageUrl;
  final double totalDistance; // km
  final int totalDurationSec;
  final int totalTrash;
  final List<String> badges;

  const PloggingUser({
    required this.id,
    required this.name,
    this.profileImageUrl = '',
    this.totalDistance = 0,
    this.totalDurationSec = 0,
    this.totalTrash = 0,
    this.badges = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'profileImageUrl': profileImageUrl,
    'totalDistance': totalDistance,
    'totalDurationSec': totalDurationSec,
    'totalTrash': totalTrash,
    'badges': badges,
  };

  factory PloggingUser.fromMap(Map<String, dynamic> map, {String? id}) {
    final name = map['name'];
    return PloggingUser(
      id: id ?? (map['id'] as String? ?? ''),
      name: name is String && name.trim().isNotEmpty ? name : '이름 없는 플로거',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      totalDistance: (map['totalDistance'] as num?)?.toDouble() ?? 0,
      totalDurationSec: (map['totalDurationSec'] as num?)?.toInt() ?? 0,
      totalTrash: (map['totalTrash'] as num?)?.toInt() ?? 0,
      badges: List<String>.from(map['badges'] as List? ?? const []),
    );
  }
}
