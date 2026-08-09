# JSPEAK: Global Communication Onboard

객실승무원 전용 기내대화 외국어(영어·일본어·중국어) 학습 앱.
콘텐츠는 Google 스프레드시트에서 관리하고, 앱은 동기화 후 **완전 오프라인**으로 동작한다.

## 아키텍처 개요

```
Google Spreadsheet (비공개, 콘텐츠 CMS)
        │
        ▼
Apps Script JSON API  (apps_script/code.gs — HTML UI 없음)
        │  HTTPS JSON
        ▼
Flutter 앱
  ├─ 콘텐츠: Hive에 JSON 저장 → 메모리 로드 (오프라인)
  ├─ 오디오: URL 해시 키로 기기에 캐시 (오프라인 재생)
  └─ UI: go_router (웹 확장 시 URL 그대로 사용)
```

- 서버 DB 없음, 로그인 없음, 개인정보 수집 없음
- 지금은 **Android APK만** 배포. 웹(PWA) 확장은 `flutter build web`으로 가능하도록 준비됨

## 대상 기기: Galaxy Tab Active 5

UI는 **Samsung Galaxy Tab Active 5** (8.0", WUXGA 1920×1200, 16:10) 기준으로 최적화되어 있다.

| 항목 | 값 |
|------|-----|
| 논리 해상도 (세로) | 600 × 960 dp |
| 논리 해상도 (가로) | 960 × 600 dp |
| 최소 터치 영역 | 52 dp |
| 카테고리 그리드 | 세로 3열 / 가로 4열 |

레이아웃 상수: `lib/core/config/active5_layout.dart`

Chrome에서 Active 5 크기로 미리보기:

```bash
# 가로 (기본)
flutter run -d chrome --web-browser-flag="--window-size=960,600"

# 세로
flutter run -d chrome --web-browser-flag="--window-size=600,960"
```

## 폴더 구조

```
lib/
├── main.dart                  # Hive 초기화 + ProviderScope
├── app/
│   ├── jspeak_app.dart        # MaterialApp.router
│   ├── router.dart            # go_router 경로 정의
│   └── providers.dart         # Riverpod 상태 (콘텐츠, 오디오)
├── core/
│   ├── config/app_config.dart # CONTENT_URL (--dart-define)
│   ├── constants/labels.dart  # 언어/카테고리 표시명·아이콘
│   ├── theme/app_theme.dart
│   └── services/audio_player_service.dart
├── data/
│   ├── models/                # Sentence, ContentBundle
│   ├── datasources/
│   │   ├── remote/            # 콘텐츠 JSON fetch
│   │   └── local/             # Hive 저장, 오디오 캐시
│   └── repositories/          # ContentRepository (UI의 유일한 진입점)
├── features/                  # 화면: home / category / sentences / search / settings
└── shared/widgets/            # SentenceCard 등 공용 위젯
apps_script/code.gs            # 시트 → JSON API (Apps Script에 붙여넣기)
```

## 시작하기

### 1. Apps Script API 배포

`apps_script/code.gs`를 스프레드시트의 Apps Script에 붙여넣고 웹 앱으로 배포한다.
(파일 상단 주석에 절차 있음. 시트 전체공개 불필요.)

**코드 저장 후 반드시 "새 버전"으로 재배포**해야 한다. 저장만 하면 URL은 예전 코드를 계속 쓴다.

배포가 맞게 됐는지 브라우저에서 확인:

| URL | 기대 결과 |
|-----|-----------|
| `CONTENT_URL?jspeak_ping=1` | `{"version":2,"audioProxy":true}` |
| `CONTENT_URL?audio=파일ID` | `{"mime":"audio/...","data":"base64..."}` (오디오 데이터) |
| `CONTENT_URL` | JSON의 `audio` 필드가 `.../exec?audio=파일ID` 형태 |

> `/exec/audio/파일ID` 경로는 Apps Script에서 인식되지 않아 JSON이 나올 수 있다. **`?audio=` 방식만** 사용한다.

위 세 가지 중 하나라도 JSON 문장 목록이 나오면 **아직 예전 코드가 배포된 상태**다.

**오디오 프록시 최초 설정 (UrlFetch 권한, 1회):**

1. Apps Script 편집기 → 프로젝트 설정 → **"appsscript.json 매니페스트 파일 표시"** 켜기
2. `apps_script/appsscript.json` 내용을 편집기의 `appsscript.json`에 반영 (또는 `authorizeOnce` 실행 시 자동 요청)
3. 함수 목록에서 **`authorizeOnce`** 선택 → ▶ **실행** → Google 계정 **권한 허용**
   - 필요 권한: 스프레드시트, Drive 읽기, **외부 URL 요청** (`script.external_request`)
4. **배포 > 배포 관리 > 새 버전**으로 웹앱 재배포
5. Drive 오디오 파일은 **「링크가 있는 모든 사용자」** 로 공유

`?audio=` 응답에 `script.external_request` 권한 오류가 나오면 3~4단계를 아직 안 한 것이다.

### 2. 실행 / 빌드

```bash
# 개발 실행 (URL 없이 실행하면 assets/sample_content.json 샘플로 동작)
flutter run --dart-define=CONTENT_URL=https://script.google.com/macros/s/XXXX/exec

# 배포용 APK
flutter build apk --release --dart-define=CONTENT_URL=https://script.google.com/macros/s/XXXX/exec

# 테스트 / 웹 빌드 (Gradle 불필요, 컴파일 검증용)
flutter test
flutter build web --release
```

> Windows + 보안 프로그램 환경에서 Gradle이
> "Could not move temporary workspace" 오류로 APK 빌드에 실패할 수 있다
> (gradle/gradle#31438 — 백신의 파일 잠금과 충돌하는 알려진 문제).
> 이 경우 `scripts\build_apk_with_retry.ps1`로 재시도하거나,
> 다른 PC/CI(GitHub Actions 등)에서 빌드하면 된다.
> 현재 프로젝트는 Gradle 9.1 + AGP 8.13으로 올려 둔 상태.

URL을 빌드 시점에 주입하므로, 나중에 Firebase Hosting의 `content.json` 등으로
바꿔도 앱 코드는 수정할 필요가 없다.

### 3. 스프레드시트 컬럼 (Sentences 시트)

| 열 | 필드 | 설명 |
|----|------|------|
| A | language | English / Japanese / Chinese |
| B | category | 업무 카테고리 (예: 식사 서비스) |
| C | sentence | 외국어 문장 |
| D | pronunciation | 발음 |
| E | korean | 한국어 번역 |
| F | audio | Google Drive **파일 ID** 또는 **공유 링크** (`.../file/d/.../view` 등) |
| G | popular | 별 개수 (숫자) |
| H | important | 필수 여부 (Yes/No) |

새 카테고리를 추가하면 `lib/core/constants/labels.dart`의 `categoryIcons`에
아이콘을 매핑해 주면 된다 (없으면 기본 아이콘 사용).

## 동작 방식

- **최초 실행**: 콘텐츠 동기화 → Hive 저장. 이후 오프라인에서 즉시 사용 가능
- **동기화 실패/URL 미설정**: `assets/sample_content.json` 샘플 콘텐츠로 폴백 (개발·데모용)
- **동기화**: 홈에서 당겨서 새로고침, 또는 설정 > 지금 동기화 (전체 교체 방식)
- **오디오**: 재생 시 자동 캐시. 설정 > "오디오 전체 다운로드"로 비행 전 일괄 저장
- **문장 ID**: `md5(언어|카테고리|문장)` — 시트 행 순서가 바뀌어도 안정적

## 웹/Firebase 확장 시 (나중에)

- 프로젝트는 이미 web 플랫폼 포함: `flutter build web` 바로 가능
- 오디오 캐시는 웹에서 자동으로 스트리밍 폴백 (`AudioCacheDataSource`)
- 접근 제한이 필요하면 `features/auth/`로 Google Sign-In 레이어만 추가
- UI·Repository·모델·라우팅은 그대로 재사용
