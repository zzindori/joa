# JoA 프로젝트

## 개요
Google Gemini 2.5 Flash Image API를 사용해 AI 이미지를 생성하는 Flutter 앱.
풍경·여자·남자 카테고리와 체형 옵션, 날씨 연동, 이어 만들기, 프리미엄 구독 기능을 제공한다.

## 프로젝트 구조
```
lib/
├── main.dart               # 전체 앱 코드 (단일 파일)
├── image_db.dart           # SQLite CRUD (ImageDB 클래스)
├── db_factory.dart         # 조건부 export (mobile/web)
├── db_factory_mobile.dart  # sqflite + path_provider
├── db_factory_web.dart     # sqflite_common_ffi_web
├── download_helper.dart    # 조건부 export (mobile/web)
├── download_mobile.dart    # Gal 갤러리 저장
├── download_web.dart       # dart:html Blob 다운로드
├── qr_scanner_view.dart    # 조건부 export (mobile/web)
├── qr_scanner_view_io.dart # MobileScanner (Android)
└── qr_scanner_view_web.dart# jsQR (Web)

api/
├── image.js        # Gemini 이미지 생성 (Vercel serverless)
└── redeem.js       # 구독 코드 검증 (Vercel serverless)

scripts/
└── gen_codes.js    # 구독 코드 생성기 (오너용)

assets/
└── app_icon.png

web/
├── index.html      # jsQR CDN 추가됨
├── sqflite_sw.js   # SQLite web worker
└── sqlite3.wasm    # SQLite WASM
```

## 주요 기능
- **카테고리**: 풍경 🌄 / 여자 👩 / 남자 👨
- **체형 선택**: 슬림·보통·통통·뚱뚱 → 프롬프트에 반영 (여자·남자)
- **날씨코디**: wttr.in API 기온 기반 착장 자동 조정
- **이미지 히스토리**: SQLite BLOB 저장, 최대 100장, 하단 썸네일 스크롤
- **이어 만들기**: 썸네일 길게 눌러 핀 고정 → 해당 사진 기반으로 연속 생성, 묶음(family) 관리
- **프리미엄 구독**: 무료 5장 → 연간 이용권 → 하루 30장

## 이어 만들기 시스템
- 썸네일 길게 누르기 → "이 사진으로 이어 만들기" 선택 → 핀 고정
- 핀 고정 시 장면·착장·포즈·조명 선택 UI 표시 (계단식 선택, 1행)
- `_refMap`: `{childFilename: parentFilename}` 으로 부모 관계 저장 (Hive joa_settings)
- `_findRoot(filename)`: 부모 체인 타고 올라가 묶음 루트 반환
- 이어 만들기 모드에서만 썸네일이 해당 묶음 사진만 표시
- 일반 모드: 썸네일 전체 flat list

## 이어 만들기 옵션 (계단식 선택 UI)
단계별로 마지막에 선택한 항목만 아이콘+글자 표시, 나머지는 아이콘만.

| 단계 | 옵션 | 비고 |
|------|------|------|
| 1 장면 | 카페/야외공원/도시거리/해변/실내/파티/스튜디오/헬스장/레스토랑/루프탑 | 장면 바뀌면 착장 자동 리셋 |
| 2 착장 | 장면에 따라 필터됨 (해변→비키니/원피스/래쉬가드/커버업 등) | |
| 3 포즈 | 정면전신/일상포즈/캔디드/진짜셀카/거울셀카 | |
| 4 조명 | 자연광/황금빛/야경/흐린날/스튜디오 | |

### 장면-착장 매핑
- 카페: 캐주얼·오피스룩·스트릿·미디드레스·미니드레스
- 야외공원: 캐주얼·스트릿·스포츠·요가복·미디·미니드레스·한복
- 도시거리: 캐주얼·오피스룩·스트릿·미디·미니드레스·포멀·파티룩
- 해변: 비키니·원피스수영복·래쉬가드·커버업·캐주얼·스포츠
- 파티: 파티룩·칵테일드레스·이브닝가운·미디·미니드레스·포멀·한복
- 헬스장: 스포츠·요가복·캐주얼
- 레스토랑: 캐주얼·오피스룩·미디·미니드레스·칵테일드레스·포멀·파티룩
- 스튜디오: 전체 허용

## API
- **모델**: `gemini-2.5-flash-image` — 이미지 생성 전용 모델이라 `gemini-3.5-flash`로 임의로 올리면 안 됨(이미지 출력을 지원 안 할 수 있음)
- **엔드포인트**: `https://generativelanguage.googleapis.com/v1beta/models/...`
- **이미지 비율**: 9:16 (세로형)
- **응답 형식**: `inlineData.data` (base64)
- 2026-07-10: `main.dart`의 안 쓰이던 `_geminiModel` 상수(죽은 코드) 제거, `api/image.js`는 `process.env.GEMINI_MODEL || 'gemini-2.5-flash-image'`로 변경 — 필요 시 Vercel 환경변수로 이미지 모델을 바꿀 수 있음(기본값은 유지)

## 빌드 방법

### APK 빌드

```bash
flutter build apk --release
adb -s 100.83.226.118:5555 install -r build/app/outputs/flutter-apk/app-release.apk
```

- API 키는 빌드 시 주입하지 않음 — Vercel 프록시를 통해 처리
- 릴리즈 서명은 현재 debug 키 사용 (별도 keystore 미설정)

### 빌드 결과물

```
build/app/outputs/flutter-apk/app-release.apk
```

### 웹 빌드 및 Vercel 배포

```bash
flutter build web
cp api/image.js build/web/api/image.js     # 반드시 복사!
cp api/redeem.js build/web/api/redeem.js   # 반드시 복사!
vercel deploy build/web --prod --yes
```

> **주의**: `vercel deploy build/web`은 `build/web` 파일만 배포.
> `api/*.js`를 반드시 `build/web/api/`에 복사해야 최신 버전 반영됨.

## Vercel 환경변수 (vercel env add)
- `GEMINI_API_KEY`: Gemini API 키
- `CODE_SECRET`: 구독 코드 HMAC 서명 비밀키 (설정 완료)

## 의존 패키지
- `http`: API 호출
- `hive_flutter`: 설정 영구 저장 (joa_settings 박스만 사용)
- `sqflite`: 이미지 히스토리 SQLite 저장 (Android)
- `sqflite_common_ffi_web`: 이미지 히스토리 SQLite 저장 (Web)
- `path_provider`: 모바일 DB 경로
- `path`: 경로 조합
- `url_launcher`: 스마트스토어 링크 열기
- `gal`: Android 갤러리 저장
- `mobile_scanner`: QR 스캐너 (Android)

## 배포
- **웹앱 URL**: https://web-tau-nine-22.vercel.app
- **GitHub**: https://github.com/zzindori/joa
- Vercel CLI로 직접 배포 (GitHub 자동 배포 아님)

## API 동작 방식
- `api/image.js`: Gemini 호출 → base64 변환 → Flutter 전달 (CORS 우회)
- `api/redeem.js`: HMAC 서명으로 코드 검증, 성공 시 1년 만료일 반환
- Flutter 웹이 직접 Gemini를 fetch하면 CORS 오류 → 항상 서버 경유

## 프리미엄 시스템

### 구조
- **무료**: 5장 (평생, Hive `freeUsed` 카운터)
- **구독**: 연간 이용권 → 하루 30장 (일 자정 초기화)
- **결제**: 네이버 스마트스토어 → 이메일 자동 발송 코드 → 앱 입력

### 스마트스토어
- URL: https://smartstore.naver.com/wowhit (이용권 상품 페이지 추가 필요)
- URL: https://m.smartstore.naver.com/wowhit/products/13625209650

### 코드 생성 (오너용)
```bash
# 코드 10개 생성 (1~10번)
CODE_SECRET=your_secret node scripts/gen_codes.js 10 1

# 코드 20개 생성 (11번부터)
CODE_SECRET=your_secret node scripts/gen_codes.js 20 11
```
- 생성된 코드를 스마트스토어 디지털상품 자동발송 코드 목록에 등록
- CODE_SECRET는 Vercel 환경변수와 동일한 값 사용

### Hive 박스 (joa_settings)
- freeUsed, subExpiry, dailyCount, dailyDate, usedCodes, refMap

### SQLite DB (joa_images)
```sql
CREATE TABLE joa_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filename TEXT UNIQUE NOT NULL,
  bytes BLOB NOT NULL,
  created_at TEXT NOT NULL,
  saved_to_gallery INTEGER NOT NULL DEFAULT 0
)
```
- 최대 100장. 101장째부터 가장 오래된 것(갤러리 저장된 것 우선) 삭제 확인 다이얼로그
- `ImageDB.markSaved(filename)`: 갤러리 저장 완료 마킹

---

## 변경 히스토리

### 2026-06-15
- 이어 만들기 포즈 옵션 5종 추가: 정면전신/일상포즈/캔디드/진짜셀카/거울셀카
- 진짜 셀카: 팔 뻗어 폰 들고 찍는 모습 / 거울 셀카: 거울 반사로 찍는 모습 분리
- 착장 16종으로 세분화 (해변: 비키니·원피스·래쉬가드·커버업 등)
- 장면-착장 연동 (SceneType → 허용 RefOutfitType 필터)
- 이어 만들기 선택바 계단식 UI: 마지막 선택 단계만 아이콘+글자, 나머지 아이콘만
- 이어 만들기 선택바 1행 유지 (조명 포함 4개 항목 + 생성 버튼)
- 이미지 생성 로딩 중 팁 회전 표시 (3초마다, 6개 팁, 도트 인디케이터)

### 2026-06-07 (이후)
- 이어 만들기 기능 전면 개편
  - 썸네일 길게 누르기 → 핀 고정 → ref 모드 진입
  - 묶음(family) 관리: `_refMap` + `_findRoot()` 로 계보 추적
  - ref 모드일 때만 썸네일에 묶음 필터 표시, 일반 모드는 flat list
  - 이어 만들기 상단 바 제거 → 전체 버튼으로 대체
- SQLite BLOB 기반 이미지 히스토리 (Hive base64에서 마이그레이션)
  - `image_db.dart`, `db_factory.dart` 추가
  - 100장 초과 시 삭제 확인 다이얼로그 (썸네일 + 날짜 + 저장 여부 표시)
  - 100장 도달 시 안내 다이얼로그 (앱 속도 유지 안내)
- 웹 QR 스캐너 (jsQR CDN)
- Gemini API 키 저장 버그 수정 (settingsBox null 안전 처리)

### 2026-06-07
- 프리미엄 구독 시스템 추가 (무료 5장 → 연간 이용권)
- 일일 사용 한도 (30장/일, 자정 초기화)
- 구독 코드 검증 API (`api/redeem.js`, HMAC 기반)
- 코드 생성 스크립트 (`scripts/gen_codes.js`)
- AppBar 사용량 표시 + 설정 다이얼로그
- `url_launcher` 패키지 추가 (스마트스토어 링크)

### 2026-06-06
- Gemini 2.5 Flash Image로 전환 (xAI Grok 대체)
- Hive 기반 이미지 히스토리 영구 저장
- 날씨 착장 로직: 기온 범위 기반으로 수정 (23°C = 가벼운 긴소매)
- CORS 수정: api/image.js에서 서버 base64 변환
- 이미지 영역 다운로드 FAB 추가

### 2026-06-05
- CLAUDE.md 최초 작성
- 웹앱으로 전환
- Flutter web 플랫폼 추가
