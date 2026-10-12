# Ploggy (플로깅 앱)

Flutter + Firebase 기반의 조깅 & 쓰레기줍기(플로깅) 기록/공유 앱입니다.

## 주요 기능
- **조깅 기록**: 실시간 타이머, 거리/스텝/시간 측정, 지도 경로 표시
- **쓰레기 분류**: 사진 촬영/업로드, AI 분류 결과, 안내 및 기록 저장
- **플로깅 다이어리**: 나만의 조깅/플로깅 기록 작성 및 관리
- **커뮤니티**: 게시글 작성/공유, 랭킹, 뱃지, 피드(모아보기)
- **모던 UI/UX**: Figma 기반 와이어프레임, 카드/섹션 기반의 깔끔한 디자인
- **Firebase 연동**: Firestore 실시간 데이터, 인증(선택), 이미지 업로드(선택)

## 폴더 구조
```
plogging_app/
├── lib/
│   ├── main.dart                # 앱 진입점
│   ├── firebase_options.dart    # Firebase 설정
│   ├── screens/                # 주요 화면(홈, 다이어리, 조깅, 쓰레기, 커뮤니티 등)
│   ├── widgets/                # 재사용 위젯(쓰레기 분류 등)
│   └── services/               # Firebase 등 서비스 연동
├── pubspec.yaml                # Flutter 패키지 의존성
├── README.md                   # 프로젝트 설명
└── ...
```

## 실행 방법 (아주 상세하게)

### 1. **필수 환경 준비**
- [Flutter 설치](https://docs.flutter.dev/get-started/install) (최신 버전 권장)
- [Firebase 프로젝트 생성](https://console.firebase.google.com/)
- Android/iOS 에뮬레이터 또는 Chrome(웹) 준비

### 2. **프로젝트 클론 및 패키지 설치**
```bash
git clone <이 저장소 주소>
cd flogging_app
flutter pub get
```

### 3. **Firebase 연동**
1. Firebase 콘솔에서 프로젝트 생성
2. Android/iOS/Web 앱 등록 및 `google-services.json`, `GoogleService-Info.plist`, 웹 설정값 발급
3. `lib/firebase_options.dart`에 웹 설정값 반영 (FlutterFire CLI 또는 직접 입력)
4. Firestore Database 활성화 및 규칙 완화(테스트용):
   ```
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```

### 4. **실행 (웹/모바일 모두 지원)**
- **웹 실행**
  ```bash
  flutter run -d chrome
  ```
- **Android/iOS 실행**
  ```bash
  flutter run -d <android|ios>
  ```
- **에뮬레이터/실기기에서 실행**
  - Android Studio, VSCode 등에서 디바이스 선택 후 실행

### 5. **주요 사용법**
- **홈**: 오늘의 플로깅, 카테고리, 모아보기 등
- **카테고리/하단바**: 다이어리, 쓰레기, 조깅, 커뮤니티 탭 이동
- **조깅**: Start → 일시정지/재시작/끝내기, 실시간 타이머
- **다이어리/커뮤니티**: + 버튼으로 글 작성, Firestore에 저장됨
- **쓰레기 분류**: 사진 촬영/업로드, AI 분류 결과 확인

### 6. **개발/실행 시 주의사항**
- Firestore 규칙을 테스트 후 반드시 강화하세요!
- Firebase 연동 오류 시 `firebase_options.dart` 및 콘솔 설정 재확인
- 웹에서 Firestore 사용 시 CORS, 인증, API 키 등 환경설정 주의
- pubspec.yaml의 패키지 버전 호환성 확인

### 7. **주요 사용 패키지**
- `firebase_core`, `cloud_firestore` (필수)
- `image_picker`, `provider` 등 (선택)
