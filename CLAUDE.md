# JoA 프로젝트

## 개요
Google Gemini 2.5 Flash Image API를 사용해 AI 이미지를 생성하는 Flutter 앱.
풍경·여자·남자 카테고리와 체형 옵션, 날씨 연동, 프리미엄 구독 기능을 제공한다.

## 프로젝트 구조
```
lib/
└── main.dart       # 전체 코드 (단일 파일)

api/
├── image.js        # Gemini 이미지 생성 (Vercel serverless)
└── redeem.js       # 구독 코드 검증 (Vercel serverless)

scripts/
└── gen_codes.js    # 구독 코드 생성기 (오너용)

assets/
└── app_icon.png
```

## 주요 기능
- **카테고리**: 풍경 🌄 / 여자 👩 / 남자 👨
- **체형 선택**: 슬림·보통·통통·뚱뚱 → 프롬프트에 반영 (여자·남자)
- **날씨코디**: wttr.in API 기온 기반 착장 자동 조정
- **이미지 히스토리**: Hive(IndexedDB/파일) 저장, 하단 썸네일 스크롤
- **프리미엄 구독**: 무료 5장 → 연간 이용권 → 하루 10장

## API
- **모델**: `gemini-2.5-flash-image`
- **엔드포인트**: `https://generativelanguage.googleapis.com/v1beta/models/...`
- **이미지 비율**: 9:16 (세로형)
- **응답 형식**: `inlineData.data` (base64)

## 환경변수

### Android 빌드 시
```bash
flutter build apk --dart-define=GEMINI_API_KEY=your_key
```

### Vercel 환경변수 (vercel env add)
- `GEMINI_API_KEY`: Gemini API 키
- `CODE_SECRET`: 구독 코드 HMAC 서명 비밀키 (설정 완료)

## 의존 패키지
- `http`: API 호출
- `hive_flutter`: 이미지 히스토리 + 설정 영구 저장
- `url_launcher`: 스마트스토어 링크 열기
- `gal`: Android 갤러리 저장

## 배포
- **웹앱 URL**: https://web-tau-nine-22.vercel.app
- **GitHub**: https://github.com/zzindori/joa
- Vercel CLI로 직접 배포 (GitHub 자동 배포 아님)

## 웹 빌드 및 배포
```bash
flutter build web
cp api/image.js build/web/api/image.js     # 반드시 복사!
cp api/redeem.js build/web/api/redeem.js   # 반드시 복사!
vercel deploy build/web --prod --yes
```
- **주의**: `vercel deploy build/web`은 `build/web` 파일만 배포함.
  api/*.js를 반드시 `build/web/api/`에 복사해야 최신 버전 반영됨.

## API 동작 방식
- `api/image.js`: Gemini 호출 → base64 변환 → Flutter 전달 (CORS 우회)
- `api/redeem.js`: HMAC 서명으로 코드 검증, 성공 시 1년 만료일 반환
- Flutter 웹이 직접 Gemini를 fetch하면 CORS 오류 → 항상 서버 경유

## 프리미엄 시스템

### 구조
- **무료**: 5장 (평생, Hive `freeUsed` 카운터)
- **구독**: 연간 이용권 → 하루 10장 (일 자정 초기화)
- **결제**: 네이버 스마트스토어 → 이메일 자동 발송 코드 → 앱 입력

### 스마트스토어
- URL: https://smartstore.naver.com/wowhit (이용권 상품 페이지 추가 필요)
- 구매 완료 시 이메일로 코드 자동 발송 설정 필요

### 코드 생성 (오너용)
```bash
# 코드 10개 생성 (1~10번)
CODE_SECRET=your_secret node scripts/gen_codes.js 10 1

# 코드 20개 생성 (11번부터)
CODE_SECRET=your_secret node scripts/gen_codes.js 20 11
```
- 생성된 코드를 스마트스토어 디지털상품 자동발송 코드 목록에 등록
- CODE_SECRET는 Vercel 환경변수와 동일한 값 사용

### Hive 박스
- `joa_history`: 이미지 base64 (키=파일명)
- `joa_settings`: freeUsed, subExpiry, dailyCount, dailyDate, usedCodes

## 변경 히스토리

### 2026-06-07
- 프리미엄 구독 시스템 추가 (무료 5장 → 연간 이용권)
- 일일 사용 한도 (10장/일, 자정 초기화)
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
