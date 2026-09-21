# AI Smart Calculator

MyBranch 포트폴리오 **브랜치앱** — Flutter 웹/모바일 반응형 AI 스마트 계산기.  
독립 Firebase Firestore + Github → Netlify CI/CD.

- Github: https://github.com/nfriend02/mybcalculator  
- Netlify: https://mybcalculator.netlify.app

## Feature-Sliced Design (FSD)

```
lib/
├── main.dart                 # 진입점 (Firebase + dotenv + 라우팅)
├── firebase_options.dart     # .env 기반 FirebaseOptions
├── app/                      # DI · Router · Theme
├── pages/                    # 화면 조합 레이어
├── features/                 # 기능 슬라이스 (ui / model / lib)
├── entities/                 # 비즈니스 엔티티
└── shared/                   # config · api · ui · services
    └── services/firestore_service.dart
```

의존 방향: `pages → features → entities → shared` (`app`은 배선만).

## 주요 기능

| 기능 | 경로 | 설명 |
|------|------|------|
| 계산기 + 음성/자연어 | `/calculator` | 버튼 계산, "삼십 나누기 삼은?", 금액 표현 |
| 환율 | `/currency` | USD/EUR/JPY 등 → KRW |
| 날씨 | `/weather` | `/api/weather` 프록시 |
| 단위 변환 | `/units` | 길이·무게 |
| 알람/타이머 | `/alarm` | 분 단위 타이머 |
| 일정 / 지출 | `/schedule` `/expense` | Firestore 연동 (설정 시) |
| 업로드 | `/upload` | Storage + 포트폴리오 체크리스트 |

## 반응형 규칙

- **상단 탭 네비**: 모든 화면에서 가로 스크롤 탭으로 이동
- **데스크톱 / 모바일** 동일 탭 셸 + 넓은 화면에서는 계산기 좌우 분할
- 목록은 **페이지당 10개** 클릭 이동 (`PagedListView`)

## 로컬 실행

```bash
cp .env.example .env
# Firebase / API 키 입력

flutter pub get
flutter run -d chrome
# 또는
flutter run   # 모바일 디바이스
```

Firebase 키가 없으면 **오프라인 데모 모드**로 UI만 동작합니다.

## Firebase

1. Firebase 콘솔에서 웹 앱 생성 → `.env`에 키 입력  
2. Firestore 인덱스: `firestore.indexes.json` (`createdAt`, `status`)  
3. 규칙: `firestore.rules`  
4. CRUD: `lib/shared/services/firestore_service.dart`

## Github → Netlify

1. 이 저장소를 Netlify에 연결 (`main` 브랜치)  
2. Build settings는 `netlify.toml` 자동 적용  
3. **Environment variables**에 `.env.example`과 동일한 키 등록  
4. `main` 병합(PR merge) 시 `netlify/build.sh`가 Flutter 웹 빌드  
5. `/api/*` → Netlify Functions (`weather`, `exchange`)

### 업로드 체크리스트 (메인앱 전시용)

- [ ] Github branch URL 정상
- [ ] 아이콘 공개 (`web/icons/Icon-512.png`)
- [ ] 설명 200자 이내 (`APP_DESCRIPTION`)
- [ ] 제작자/팀명 (`APP_AUTHOR`)

## 예시 코드 위치

1. `lib/main.dart` — Firebase 초기화 및 라우팅  
2. `lib/shared/services/firestore_service.dart` — Firestore CRUD  
3. `lib/pages/upload/upload_page.dart` — `UploadPage` 업로드 예시  

## PR 워크플로

1. feature 브랜치에서 작업  
2. PR → `main`  
3. 리뷰 후 merge → Netlify 자동 배포  
4. 메인 포트폴리오 앱은 배포 URL만 연결·전시

## 라이선스

Private / MyBranch portfolio use.
