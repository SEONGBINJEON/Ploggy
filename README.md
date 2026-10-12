# Ploggy (플로깅 앱)

**An AI-powered eco running app for smarter plogging**

조깅을 하면서 쓰레기를 줍는 플로깅(Plogging)을 기록하고 공유하는 Flutter + Firebase 앱입니다.
쓰레기 사진을 찍으면 온디바이스 AI가 종류를 분류하고, 멜버른의 3색 쓰레기통 기준으로 버리는 방법을 안내합니다.

## 주요 기능
- **AI 쓰레기 분류**: 사진 촬영/앨범 업로드 → MobileNetV2 기반 TFLite 모델이 6종(glass, metal, organics, paper, plastic, trash)으로 분류 → 재활용(노란 뚜껑)·음식물/유기물(초록 뚜껑)·일반(빨간 뚜껑) 통 안내, 기록 저장
- **조깅 기록**: 실시간 타이머·거리·속도, 지도에 경로 표시, 경로 저장, Google 지도 경로 링크로 공유
- **주변 쓰레기통 지도**: 현재 위치 1km 안의 쓰레기통·재활용 수거함 표시 (OpenStreetMap)
- **플로깅 다이어리**: 오늘의 조깅(경로 미니맵 포함) + 사진을 붙인 나만의 일기
- **커뮤니티**: 누적 거리 랭킹, 뱃지 16종(거리·시간대·연속 기록·쓰레기 수거·날씨·글 작성), 게시글 피드, 조깅 팁 영상

## AI 모델
| 항목 | 내용 |
|---|---|
| 데이터 | TrashNet(정확도 낮음) → TACO 데이터셋의 bbox를 잘라 분류 데이터로 가공 |
| 모델 | MobileNetV2 (1.00, 224) 전이학습, 출력 6클래스 + Softmax |
| 성능 | 검증 정확도 약 87% (10 epoch) |
| 배포 | `handout_mobile_20250815_0505/` — `plogging_224_fp16.tflite`(기본, 4.5MB), `plogging_224_dynamic.tflite`(대체) |
| 입력 | `[1, 224, 224, 3]` float32 RGB 0~255 (정규화는 모델 안에 포함) |

## 기술 스택
Flutter 3.32 (Dart 3.8) · Firebase Auth / Cloud Firestore / Storage · Hive(기기 저장) · Provider ·
google_maps_flutter · geolocator · tflite_flutter · image_picker · share_plus

## 폴더 구조
```
lib/
├── main.dart                 # 앱 진입점, 하단 탭(상태 유지)
├── app_navigation.dart       # 탭 인덱스
├── firebase_options.dart     # Firebase 웹 설정 (Android는 google-services.json 사용)
├── models/                   # JogRecord(Hive), TrashRecord, DiaryEntry, CommunityPost, PloggingUser, BinLocation
├── screens/                  # 홈, 다이어리, 쓰레기 분류, 조깅, 커뮤니티 등
├── services/                 # Firebase, AI 분류, 뱃지, 쓰레기통 위치, 날씨, 위치
├── utils/                    # 쓰레기 라벨·배출 안내, 경로 공유 링크
└── widgets/                  # 쓰레기 분류기, 경로 미니맵, 뱃지 팝업, 사진 첨부
test/                         # 단위 테스트
firestore.rules, storage.rules, firebase.json   # Firebase 보안 규칙
```

## 실행 방법

### 1. 준비
- [Flutter 설치](https://docs.flutter.dev/get-started/install) (3.32 이상 권장)
- Android Studio(Android SDK) 또는 Android 기기

### 2. 패키지 설치
```bash
flutter pub get
```

### 3. Google Maps API 키 (Android)
API 키는 깃에 올리지 않습니다. `android/local.properties`에 아래 줄을 추가하세요. (이 파일은 `.gitignore`에 포함)
```
MAPS_API_KEY=발급받은_키
```
Google Cloud Console에서 키에 **Android 앱 제한(패키지 이름 + SHA-1)** 을 걸어 두는 것을 권장합니다.

### 4. Firebase
- Android: `android/app/google-services.json` 사용
- Web: `lib/firebase_options.dart`
- Firestore·Storage를 활성화한 뒤 **보안 규칙을 꼭 적용하세요.** 전체 공개 규칙(`allow read, write: if true`)은 쓰지 마세요.
  - 콘솔: Firestore Database / Storage > 규칙 에 `firestore.rules`, `storage.rules` 내용을 붙여넣기
  - CLI: `firebase deploy --only firestore:rules,storage`

### 5. 실행·테스트
```bash
flutter run                # 연결된 Android 기기/에뮬레이터
flutter test               # 단위 테스트
flutter analyze            # 정적 분석
flutter build apk --release   # 폰에 설치할 APK (build/app/outputs/flutter-apk/app-release.apk)
```
릴리스 빌드는 아직 디버그 키로 서명됩니다. (스토어 배포 시 별도 서명 키 필요)
Maps 키에 Android 앱 제한을 걸었다면, 빌드한 PC의 디버그 키 SHA-1도 등록해야 지도가 나옵니다.
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```
웹(`flutter run -d chrome`)에서는 TFLite가 동작하지 않아 쓰레기 분류가 **데모 결과**로 표시되고, 지도는 나오지 않습니다.

### iOS
`ios/Runner/Info.plist`의 `GMSApiKey`에 iOS용 Maps 키를 넣고, Firebase 콘솔에서 받은 `GoogleService-Info.plist`를 추가해야 합니다. (아직 iOS 기기에서는 테스트하지 않았습니다)

## 데이터 출처
- 쓰레기통 위치: © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors (ODbL), Overpass API
- 날씨(날씨 뱃지): [Open-Meteo](https://open-meteo.com/) (CC BY 4.0)
- 학습 데이터: [TACO](http://tacodataset.org/) (Trash Annotations in Context)

## 알려진 한계
- Android는 조깅 중 알림(포그라운드 서비스)을 띄워 화면을 끄거나 카메라를 열어도 위치를 받습니다. iOS는 백그라운드 위치 설정을 아직 하지 않았습니다.
- "대략적인 위치"만 허용하면 조깅을 시작할 수 없습니다. (정확한 위치 필요)
- 조깅 기록·뱃지는 기기(Hive)에 저장되어, 한 기기에서 여러 계정을 쓰면 섞입니다.
- 랭킹(`leaderboard` 컬렉션)의 누적 기록은 앱이 직접 올리기 때문에 서버 검증이 없습니다.

---
영남대학교 글로벌 SW 역량 강화 프로그램 1조 캡스톤 (2025, Melbourne)
