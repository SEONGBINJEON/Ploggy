import 'package:firebase_core/firebase_core.dart';

// 웹에서 실행할 때 쓰는 Firebase 설정입니다. (Android는 android/app/google-services.json 사용)
// 공개 저장소라 실제 값은 넣지 않았습니다. 본인 Firebase 프로젝트의 웹 앱 설정값으로 바꾸세요.
// Firebase 콘솔 > 프로젝트 설정 > 내 앱 > 웹 앱 > SDK 설정 및 구성, 또는 `flutterfire configure`
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: "YOUR_WEB_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_WEB_APP_ID",
  measurementId: "YOUR_MEASUREMENT_ID",
);
