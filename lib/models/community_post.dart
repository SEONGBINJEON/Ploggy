import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `community_posts` 문서
class CommunityPost {
  final String id;
  final String userId;
  final String authorName;
  final String title;
  final String content;
  final String imageUrl;
  final DateTime createdAt;

  const CommunityPost({
    this.id = '',
    required this.userId,
    required this.authorName,
    required this.title,
    required this.content,
    this.imageUrl = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'authorName': authorName,
    'title': title,
    'content': content,
    'imageUrl': imageUrl,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory CommunityPost.fromMap(String id, Map<String, dynamic> map) {
    final createdAt = map['createdAt'];
    return CommunityPost(
      id: id,
      userId: map['userId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '플로거',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      // 저장 직후 서버 시간이 아직 없으면(null) 현재 시각으로 표시합니다.
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }
}
