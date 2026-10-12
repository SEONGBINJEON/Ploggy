import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/community_post.dart';
import '../models/diary_entry.dart';
import '../models/trash_record.dart';
import '../models/user.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  static const Duration _serverAckTimeout = Duration(seconds: 8);

  FirebaseService() {
    // 오프라인일 때 업로드가 기본값(10분) 동안 재시도하며 멈춰 있지 않도록 줄입니다.
    _storage.setMaxUploadRetryTime(const Duration(seconds: 20));
  }

  /// Firestore 쓰기는 오프라인이면 서버가 확인할 때까지 끝나지 않습니다.
  /// 기기에는 바로 반영되고 연결되면 자동으로 올라가므로, 잠깐만 기다립니다.
  /// 서버 확인을 받으면 true, 아직 올라가지 않았으면 false.
  Future<bool> _commit(Future<void> write) async {
    try {
      await write.timeout(_serverAckTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 변경 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 이메일/비밀번호로 로그인
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // 이메일/비밀번호로 회원가입
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password, String name) async {
    final UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      // 사용자 프로필 업데이트
      await userCredential.user?.updateDisplayName(name);
    } catch (e) {
      throw _handleAuthError(e);
    }

    // Firestore 프로필 저장은 실패해도 가입 자체는 성공으로 처리합니다.
    try {
      await saveUser(PloggingUser(id: userCredential.user!.uid, name: name));
    } catch (e) {
      debugPrint('사용자 프로필 저장 실패: $e');
    }
    return userCredential;
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 비밀번호 재설정 이메일 보내기
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // 인증 오류 처리
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return '해당 이메일로 등록된 사용자가 없습니다.';
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        case 'too-many-requests':
          return '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
        default:
          return '로그인 중 오류가 발생했습니다: ${e.message}';
      }
    }
    return '알 수 없는 오류가 발생했습니다.';
  }

  // ---------------------------------------------------------------------------
  // 사용자 프로필 · 랭킹
  // ---------------------------------------------------------------------------

  // 사용자 정보 저장 (본인만 읽는 비공개 프로필)
  Future<void> saveUser(PloggingUser user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap(), SetOptions(merge: true));
  }

  /// 조깅이 끝나면 랭킹용 누적 거리·시간을 올립니다.
  Future<void> addJogStats({required double distanceKm, required int durationSec}) {
    return _updateLeaderboard({
      'totalDistance': FieldValue.increment(distanceKm),
      'totalDurationSec': FieldValue.increment(durationSec),
    });
  }

  /// 쓰레기 기록을 저장하면 랭킹용 누적 수거 개수를 올립니다.
  Future<void> incrementTrashCount() {
    return _updateLeaderboard({'totalTrash': FieldValue.increment(1)});
  }

  // 랭킹은 이름과 누적 기록만 담은 공개 컬렉션(leaderboard)에서 읽습니다.
  // 예전 버전의 users 문서에는 이메일이 들어 있어서 다른 사용자에게 공개하지 않습니다.
  Future<void> _updateLeaderboard(Map<String, Object> increments) async {
    final user = currentUser;
    if (user == null) return;
    await _firestore.collection('leaderboard').doc(user.uid).set({
      'id': user.uid,
      if ((user.displayName ?? '').isNotEmpty) 'name': user.displayName,
      ...increments,
    }, SetOptions(merge: true));
  }

  /// 누적 거리 순 랭킹
  Stream<List<PloggingUser>> rankingStream({int limit = 20}) {
    return _firestore
        .collection('leaderboard')
        .orderBy('totalDistance', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PloggingUser.fromMap(doc.data(), id: doc.id))
            .toList());
  }

  // ---------------------------------------------------------------------------
  // 쓰레기 기록
  // ---------------------------------------------------------------------------

  /// 쓰레기 기록 저장. 오프라인이라 아직 서버에 올라가지 않았으면 false.
  Future<bool> saveTrashRecord(TrashRecord record) async {
    try {
      return await _commit(_firestore.collection('trash_records').doc(record.id).set(record.toMap()));
    } catch (e) {
      throw Exception('Firebase 저장 실패: $e');
    }
  }

  // 사용자의 쓰레기 기록 조회 (복합 색인 없이 동작하도록 정렬은 앱에서 합니다)
  Stream<List<TrashRecord>> getTrashRecords(String userId) {
    return _firestore
        .collection('trash_records')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrashRecord.fromMap(doc.data()))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)));
  }

  // 특정 쓰레기 기록 조회
  Future<TrashRecord?> getTrashRecord(String recordId) async {
    final doc = await _firestore.collection('trash_records').doc(recordId).get();
    if (doc.exists) {
      return TrashRecord.fromMap(doc.data()!);
    }
    return null;
  }

  // 쓰레기 기록 삭제
  Future<void> deleteTrashRecord(String recordId) async {
    await _firestore.collection('trash_records').doc(recordId).delete();
  }

  // ---------------------------------------------------------------------------
  // 플로깅 다이어리 · 커뮤니티
  // ---------------------------------------------------------------------------

  /// 오프라인이라 아직 서버에 올라가지 않았으면 false.
  Future<bool> saveDiaryEntry(DiaryEntry entry) {
    return _commit(_firestore.collection('plogging_diary').add(entry.toMap()));
  }

  Stream<List<DiaryEntry>> diaryEntriesStream(String userId) {
    return _firestore
        .collection('plogging_diary')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiaryEntry.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<void> deleteDiaryEntry(String entryId) async {
    await _firestore.collection('plogging_diary').doc(entryId).delete();
  }

  /// 오프라인이라 아직 서버에 올라가지 않았으면 false.
  Future<bool> createPost(CommunityPost post) {
    return _commit(_firestore.collection('community_posts').add(post.toMap()));
  }

  Stream<List<CommunityPost>> postsStream({int limit = 30}) {
    return _firestore
        .collection('community_posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityPost.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ---------------------------------------------------------------------------
  // 이미지 업로드
  // ---------------------------------------------------------------------------

  // 쓰레기 사진 업로드 - Firebase Storage 우선, 실패 시 기기에 저장 (모바일)
  Future<String> uploadImageBytes(Uint8List imageBytes, String fileName) async {
    final uid = currentUser?.uid ?? 'anonymous';
    try {
      return await _uploadToStorage('images/$uid/$fileName', imageBytes);
    } catch (e) {
      debugPrint('Firebase Storage 업로드 실패: $e');
      if (kIsWeb) rethrow;

      // Firebase Storage 실패 시 로컬 저장소 사용
      try {
        final localPath = await _saveImageLocally(imageBytes, fileName);
        return 'local://$localPath'; // 로컬 경로를 URL 형태로 반환
      } catch (localError) {
        debugPrint('로컬 저장소 저장도 실패: $localError');
        throw Exception('이미지 저장에 실패했습니다. Firebase Storage와 로컬 저장소 모두 사용할 수 없습니다.');
      }
    }
  }

  /// 커뮤니티·다이어리 사진처럼 다른 기기에서도 보여야 하는 이미지 업로드.
  /// 로컬 저장으로 대체할 수 없으니 실패하면 예외를 그대로 던집니다.
  Future<String> uploadSharedImage(Uint8List imageBytes, String folder) async {
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _uploadToStorage('$folder/$uid/$fileName', imageBytes);
  }

  /// 사진 업로드에 실패하면(오프라인, Storage를 쓸 수 없는 요금제 등) null을 돌려줍니다.
  /// 글·일기는 사진 없이라도 올라가도록 할 때 사용합니다.
  Future<String?> tryUploadSharedImage(Uint8List imageBytes, String folder) async {
    try {
      return await uploadSharedImage(imageBytes, folder);
    } catch (e) {
      debugPrint('사진 업로드 실패: $e');
      return null;
    }
  }

  Future<String> _uploadToStorage(String path, Uint8List imageBytes) async {
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploaded_at': DateTime.now().toIso8601String(),
      },
    );
    final uploadTask = await ref.putData(imageBytes, metadata);
    return uploadTask.ref.getDownloadURL();
  }

  // 로컬에 이미지 저장
  Future<String> _saveImageLocally(Uint8List imageBytes, String fileName) async {
    // 앱 문서 디렉토리에 images 폴더 생성
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final filePath = '${imagesDir.path}/$fileName';
    await File(filePath).writeAsBytes(imageBytes);
    return filePath;
  }
}
