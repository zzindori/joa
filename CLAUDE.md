# JoA 프로젝트

## 개요
xAI Grok API를 사용해 AI 이미지를 생성하는 Flutter 앱.
풍경·여자·남자 카테고리와 체형 옵션, 날씨 연동 기능을 제공한다.

## 프로젝트 구조
```
lib/
└── main.dart   # 전체 코드 (단일 파일)

assets/
└── app_icon.png
```

## 주요 기능
- **카테고리**: 풍경 🌄 / 여자 👩 / 남자 👨
- **체형 선택**: 슬림·보통·통통·뚱뚱 → 프롬프트에 반영 (여자·남자 카테고리)
- **날씨 연동**: wttr.in API로 현재 날씨 조회 → 날씨에 맞는 이미지 생성
- **이미지 저장**: 앱 내 히스토리 보관 + 갤러리 저장 (gal 패키지)
- **히스토리**: 하단 썸네일 가로 스크롤, 길게 누르면 저장/삭제 메뉴

## API
- **모델**: Grok Image (xAI)
- **엔드포인트**: `https://api.x.ai/v1/images/generations`
- **이미지 비율**: 9:16 (세로형)
- **응답 형식**: `b64_json` 또는 `url` 둘 다 처리

## 환경변수 (빌드 시 주입)
```bash
flutter build apk \
  --dart-define=XAI_API_KEY=your_key \
  --dart-define=GROK_BASE_URL=https://api.x.ai/v1 \
  --dart-define=GROK_IMAGE_MODEL=grok-imagine-image
```
- `XAI_API_KEY` (필수): xAI API 키
- `GROK_BASE_URL` (기본값: `https://api.x.ai/v1`)
- `GROK_IMAGE_MODEL` (기본값: `grok-imagine-image`)

## 의존 패키지
- `http`: API 호출
- `dart:html`: 브라우저 다운로드 (웹 전용)

## 배포
- **웹앱 URL**: https://web-tau-nine-22.vercel.app
- **GitHub**: https://github.com/zzindori/joa
- Vercel CLI로 직접 배포 (GitHub 자동 배포 아님)

## 웹 빌드 및 배포
```bash
flutter build web
cp api/image.js build/web/api/image.js   # 반드시 먼저 복사!
vercel deploy build/web --prod --yes
```
- **주의**: `vercel deploy build/web`은 `build/web` 안에 있는 파일만 배포함.
  `api/image.js`를 `build/web/api/`에 복사하지 않으면 이전 버전 API가 그대로 유지됨.
- XAI_API_KEY는 Vercel 환경변수로 관리 (웹 빌드 시 `--dart-define` 불필요)
- 이미지는 메모리에만 저장 (새로고침 시 히스토리 초기화)
- 갤러리 저장 → 브라우저 다운로드로 대체
- `dart:html` 사용으로 WASM 빌드 불가 (JS 빌드만 지원)

### API 동작 방식
- xAI는 항상 URL로 응답함 (`b64_json` 미지원)
- `api/image.js`가 서버에서 URL을 fetch → base64 변환 후 Flutter에 전달
- Flutter가 직접 `imgen.x.ai`를 fetch하면 CORS 오류 발생

## 주요 구현 메모

### 이미지 저장
- `_HistoryItem(Uint8List bytes, String filename)` 클래스로 메모리 관리
- `Image.memory()` 로 표시
- 다운로드: `html.Blob` + `AnchorElement` 클릭으로 처리

## 변경 히스토리

### 2026-06-06
- CORS 수정: `api/image.js`에서 xAI URL을 서버에서 base64로 변환
- 배포 절차 수정: `api/image.js`를 `build/web/api/`에 복사 후 배포
- 이미지 영역에 다운로드 버튼(FAB) 추가

### 2026-06-05
- CLAUDE.md 최초 작성
- 웹앱으로 전환: `dart:io`, `path_provider`, `gal` 제거
- `Uint8List` 기반 메모리 이미지 관리로 변경
- 갤러리 저장 → 브라우저 다운로드로 변경
- Flutter web 플랫폼 추가
