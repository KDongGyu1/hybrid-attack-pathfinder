# Hybrid Attack Path Analysis Frontend (Backend 2)

하이브리드 공격 경로 탐색 시스템의 웹 프론트엔드. 로그인/인증, 자산 목록, 감사 로그, 공격 경로 그래프 시각화 화면을 제공한다. Backend 2(NestJS API)를 통해서만 데이터를 가져오며, 그 뒤에서 Backend 1(Neo4j 탐색 엔진)의 결과가 최종적으로 그래프에 반영된다.

## 기술 스택

| 구분 | 사용 기술 |
|---|---|
| 언어 | TypeScript |
| 프레임워크 | Next.js 14 (App Router) |
| 스타일 | Tailwind CSS |
| 그래프 시각화 | Cytoscape.js 3.34 |
| HTTP 클라이언트 | axios |
| 인증 상태 관리 | React Context + sessionStorage (짧은 수명의 저장소) |

## 사전 준비

- Node.js 18 이상 (Next.js 14 요구사항)
- Backend 2 API 서버가 `http://localhost:3000`에서 실행 중이어야 함 (`hybrid-attack-path-backend` 레포 참고)

## 환경변수 설정

`.env.local` 파일에 API 서버 주소가 설정되어 있어야 한다 (이미 생성되어 있음, 없으면 아래 내용으로 생성):

```
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1
```

### 배포(프로덕션) 환경

`.env.production`에 실제 SOC 대시보드 도메인이 설정되어 있다 (2026-07-22 확정):

```
NEXT_PUBLIC_API_BASE_URL=https://hap-soc.kro.kr/api/v1
```

`NEXT_PUBLIC_*` 값은 `next build` 시점에 번들에 고정되므로, 배포 서버(`hap-soc-api`)에서 빌드를 실행하기 전에 `.env.production`이 이미 존재해야 한다. 로컬 `npm run dev`는 `.env.local`만 보고 이 파일의 영향을 받지 않는다.

## 설치 및 실행

```bash
npm install
npm run dev
```

Backend 2가 3000번 포트를 쓰고 있어서 프론트는 보통 3001번 포트로 뜬다 (터미널에 뜨는 실제 주소 확인). 브라우저에서 접속하면 로그인 화면으로 이동한다.

### 로그인 계정 (Backend 2의 데모 계정과 동일)

| 이메일 | 비밀번호 | 역할 |
|---|---|---|
| admin@hap.com | Admin1234! | ADMIN |
| analyst@hap.com | Analyst1234! | ANALYST |
| viewer@hap.com | Viewer1234! | VIEWER |

analyst/viewer 계정으로 로그인하면 감사 로그 화면에서 403(ADMIN 전용)이 뜨는 것을 확인할 수 있다 — 역할 기반 접근 제어(RBAC) 시연용으로 의도된 동작이다.

## 화면 구성

| 경로 | 설명 |
|---|---|
| `/login` | 로그인 |
| `/dashboard` | 시나리오 선택 + 공격 경로 그래프 시각화 (Cytoscape.js) |
| `/assets` | 자산 목록 (유형/환경/민감도 필터 + 페이지네이션) |
| `/logs` | 감사 로그 (ADMIN 전용, 액션/사용자 필터 + 페이지네이션) |

## 디렉터리 구조

```
src/
├── app/
│   ├── login/page.tsx       # 로그인 화면
│   ├── dashboard/page.tsx   # 대시보드 (그래프 시각화)
│   ├── assets/page.tsx      # 자산 목록
│   ├── logs/page.tsx        # 감사 로그
│   ├── layout.tsx           # AuthProvider로 전체 앱 감쌈
│   └── page.tsx             # 로그인 여부에 따라 /login 또는 /dashboard로 리다이렉트
├── components/
│   ├── AppHeader.tsx         # 공용 헤더 (사용자 정보, 네비게이션, 로그아웃)
│   └── GraphView.tsx         # Cytoscape.js 래퍼 컴포넌트
└── lib/
    ├── api.ts                # axios 인스턴스, Access 토큰 헤더 주입
    └── auth-context.tsx      # 인증 상태 관리 (React Context + sessionStorage)
```

## 알려진 제약 / 다음 단계

- 그래프 화면에서 조회 가능한 시나리오는 현재 Backend 1 엔진이 서빙하는 5개로 고정되어 있음 (`hybrid-attack-path-backend`의 README 참고)
- 로그인 세션은 `sessionStorage`에 저장되어 브라우저 탭을 닫으면 만료됨 (설계 문서 3.1 "짧은 수명의 저장소" 원칙)
- (해결됨, 2026-07-22) 자산 목록의 자산 ID와 그래프 노드 ID 체계를 통일함 (`hybrid-attack-path-backend`의 README 참고). 단, id가 같아졌을 뿐 자산 상세 화면에서 관련 그래프로 바로 연결(딥링크)하는 UI 기능 자체는 아직 없음 (TODO)
