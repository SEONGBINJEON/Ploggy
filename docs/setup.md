# 설치·실행 방법

## 1. 준비
- [Flutter](https://docs.flutter.dev/get-started/install) 3.32 이상 (개발 버전: 3.32.6)
- Android Studio(Android SDK) 또는 Android 기기
- JDK 17

## 2. 패키지 설치
```bash
flutter pub get
```

## 3. Google Maps API 키 (Android)
API 키는 저장소에 올리지 않습니다. `android/local.properties`에 아래 줄을 추가하세요. (이 파일은 `.gitignore`에 포함)
```
MAPS_API_KEY=발급받은_키
```
Google Cloud Console에서 키에 **Android 앱 제한(패키지 이름 `com.example.flogging_app` + SHA-1)** 을 걸어 두는 것을 권장합니다.
빌드하는 PC의 디버그 키 SHA-1은 아래 명령으로 확인할 수 있습니다.
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```

## 4. Firebase 연결
Firebase 프로젝트 설정 파일은 저장소에 넣지 않았습니다. 앱을 실행하려면 본인 Firebase 프로젝트를 연결하세요.

1. [Firebase 콘솔](https://console.firebase.google.com/)에서 새 프로젝트를 만듭니다.
2. **Android 앱 추가** (패키지 이름 `com.example.flogging_app`) → `google-services.json`을 받아 `android/app/`에 둡니다. (`.gitignore`에 포함돼 있어 깃에는 올라가지 않음)
3. 웹으로 실행할 때만: **웹 앱 추가** → 설정값을 `lib/firebase_options.dart`에 넣습니다. (또는 `flutterfire configure`)
4. **Authentication → 로그인 방법 → 이메일/비밀번호**를 사용 설정합니다.
5. **Firestore Database**를 만듭니다.
6. **보안 규칙을 꼭 적용하세요.** 전체 공개 규칙(`allow read, write: if true`)은 쓰지 마세요.
   - 콘솔: Firestore Database / Storage → 규칙에 [`firestore.rules`](../firestore.rules), [`storage.rules`](../storage.rules) 내용을 붙여넣고 게시
   - CLI: `firebase deploy --only firestore:rules,storage`
   - 랭킹은 `leaderboard` 컬렉션을 읽기 때문에 이 규칙이 있어야 동작합니다.
7. Storage는 선택입니다. 새 프로젝트는 요금제(Blaze)가 필요할 수 있는데, 없어도 앱은 동작합니다. (쓰레기 사진은 기기에 저장, 일기·커뮤니티 글은 사진 없이 등록)

## 5. 실행·테스트·빌드
```bash
flutter run                    # 연결된 Android 기기/에뮬레이터
flutter test                   # 단위 테스트 38개
flutter analyze                # 정적 분석
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
```
- 릴리스 빌드는 아직 디버그 키로 서명됩니다. 스토어에 올리려면 별도 서명 키가 필요합니다.
- 웹(`flutter run -d chrome`)에서는 TFLite가 동작하지 않아 쓰레기 분류가 **데모 결과**로 나오고, 지도는 표시되지 않습니다.

## 6. iOS
`ios/Runner/Info.plist`의 `GMSApiKey`에 iOS용 Maps 키를 넣고, Firebase 콘솔에서 받은 `GoogleService-Info.plist`를 추가해야 합니다. iOS 기기에서는 아직 테스트하지 않았습니다.

## 알려진 한계
- Android는 조깅 중 알림(포그라운드 서비스)을 띄워 화면을 끄거나 카메라를 열어도 위치를 받습니다. iOS 백그라운드 위치는 아직 설정하지 않았습니다.
- "대략적인 위치"만 허용하면 조깅을 시작할 수 없습니다. (정확한 위치 필요)
- 조깅 기록·뱃지는 기기(Hive)에 저장되어, 한 기기에서 여러 계정을 쓰면 섞입니다.
- 랭킹의 누적 기록은 앱이 직접 올리기 때문에 서버 검증이 없습니다.
