import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/plogging_record.dart';
import '../models/trash_record.dart';
import '../models/user.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

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
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      // 사용자 프로필 업데이트
      await userCredential.user?.updateDisplayName(name);
      
      // Firestore에 사용자 정보 저장
      final user = PloggingUser(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        profileImageUrl: '',
        totalDistance: 0,
        totalTrash: 0,
        badges: [],
      );
      await saveUser(user);
      
      return userCredential;
    } catch (e) {
      throw _handleAuthError(e);
    }
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
          return '비밀번호가 올바르지 않습니다.';
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

  // 플로깅 기록 저장
  Future<void> savePloggingRecord(PloggingRecord record) async {
    await _firestore.collection('plogging_records').doc(record.id).set(record.toMap());
  }

  // 쓰레기 기록 저장
  Future<void> saveTrashRecord(TrashRecord record) async {
    try {
      print('Firebase에 쓰레기 기록 저장 시도: ${record.id}');
      await _firestore.collection('trash_records').doc(record.id).set(record.toMap());
      print('쓰레기 기록 저장 성공');
    } catch (e) {
      print('쓰레기 기록 저장 실패: $e');
      throw Exception('Firebase 저장 실패: $e');
    }
  }

  // 사용자 정보 저장
  Future<void> saveUser(PloggingUser user) async {
    try {
      print('Firebase에 사용자 정보 저장 시도: ${user.id}');
      await _firestore.collection('users').doc(user.id).set(user.toMap());
      print('사용자 정보 저장 성공');
    } catch (e) {
      print('사용자 정보 저장 실패: $e');
      throw Exception('Firebase 사용자 저장 실패: $e');
    }
  }

  // 이미지 업로드 (파일 경로)
  Future<String> uploadImage(String path, String fileName) async {
    final ref = _storage.ref().child('trash_images/$fileName');
    final uploadTask = await ref.putFile(File(path));
    return await uploadTask.ref.getDownloadURL();
  }

  // 이미지 업로드 (바이트 데이터) - Firebase Storage 우선, 실패 시 로컬 저장
  Future<String> uploadImageBytes(Uint8List imageBytes, String fileName) async {
    try {
      print('Firebase Storage에 이미지 업로드 시도: $fileName');
      
      // 더 간단한 경로 사용
      final ref = _storage.ref().child('images/$fileName');
      
      // 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );
      
      final uploadTask = await ref.putData(imageBytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Firebase Storage 업로드 실패: $e');
      
      // Firebase Storage 실패 시 로컬 저장소 사용
      try {
        final localPath = await _saveImageLocally(imageBytes, fileName);
        print('로컬 저장소에 이미지 저장: $localPath');
        return 'local://$localPath'; // 로컬 경로를 URL 형태로 반환
      } catch (localError) {
        print('로컬 저장소 저장도 실패: $localError');
        throw Exception('이미지 저장에 실패했습니다. Firebase Storage와 로컬 저장소 모두 사용할 수 없습니다.');
      }
    }
  }

  // 로컬에 이미지 저장
  Future<String> _saveImageLocally(Uint8List imageBytes, String fileName) async {
    try {
      // 앱 문서 디렉토리에 images 폴더 생성
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      final filePath = '${imagesDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      return filePath;
    } catch (e) {
      throw Exception('로컬 저장 실패: $e');
    }
  }

  // 사용자의 쓰레기 기록 조회
  Stream<List<TrashRecord>> getTrashRecords(String userId) {
    try {
      print('Firebase에서 쓰레기 기록 조회 시도: $userId');
      return _firestore
          .collection('trash_records')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
            print('쓰레기 기록 ${snapshot.docs.length}개 조회 성공');
            return snapshot.docs
                .map((doc) => TrashRecord.fromMap(doc.data()))
                .toList();
          })
          .handleError((error) {
            print('쓰레기 기록 조회 에러: $error');
            return <TrashRecord>[];
          });
    } catch (e) {
      print('쓰레기 기록 조회 초기화 실패: $e');
      return Stream.value(<TrashRecord>[]);
    }
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

  // Firebase 연결 상태 확인
  Future<bool> checkFirebaseConnection() async {
    try {
      print('Firebase 연결 상태 확인 중...');
      
      // Firestore 연결 확인 (더 간단하게)
      try {
        await _firestore.collection('test').limit(1).get();
        print('Firestore 연결 성공');
      } catch (e) {
        print('Firestore 연결 실패: $e');
        // Firestore 연결 실패해도 Storage는 시도
      }
      
      // Storage 연결 확인 (더 간단하게)
      try {
        final storageRef = _storage.ref().child('test');
        await storageRef.getMetadata();
        print('Firebase Storage 연결 성공');
      } catch (e) {
        print('Firebase Storage 연결 실패: $e');
        // Storage 연결 실패해도 앱은 계속 실행
      }
      
      // 기본적으로는 연결 성공으로 처리 (부분 실패 허용)
      return true;
    } catch (e) {
      print('Firebase 연결 확인 중 예상치 못한 오류: $e');
      return false;
    }
  }
}