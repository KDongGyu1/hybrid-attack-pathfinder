# Hybrid Attack Path Analysis API (Backend 2)

하이브리드 공격 경로 탐색 시스템의 REST API 서버. 인증/인가, 자산·시나리오 조회, 공격 경로 그래프 조회, 감사 로그를 담당하며, Backend 1(Neo4j 기반 공격 경로 탐색 엔진)의 결과를 REST 계약에 맞게 변환해 프론트엔드에 제공하는 어댑터 역할을 한다.

## 기술 스택

| 구분 | 사용 기술 |
|---|---|
| 언어 | TypeScript 5.6 |
| 런타임 | Node.js 22.x |
| 프레임워크 | NestJS 11 |
| DB | PostgreSQL 16 (Docker) |
| ORM | TypeORM 0.3.20 |
| 인증 | JWT (Access 15분 / Refresh 7일), bcrypt 비밀번호 해싱 |
| 검증 | class-validator, class-transformer |
| API 문서 | @nestjs/swagger (Swagger UI) |
| 외부 연동 | axios (Backend 1 FastAPI 엔진 호출) |

## 사전 준비

- Node.js 22.x
- Docker Desktop (PostgreSQL 실행용)
- Backend 1 탐색 엔진(Neo4j + FastAPI) — 그래프/공격 경로 조회 기능에 필요. 레포: `hybrid-attack-pathfinder` (`feature/backend1-neo4j-engine` 브랜치)

## 아키텍처 개요

```
Frontend (Next.js) → Backend 2 (이 레포, NestJS) → Backend 1 (Neo4j + FastAPI 엔진)
                              ↓
                        PostgreSQL (계정/자산/시나리오/감사로그)
```

- `auth`, `assets`, `scenarios`, `logs` 모듈: PostgreSQL(TypeORM)에 직접 저장된 데이터 조회
- `graph` 모듈: `GraphService`가 Backend 1 FastAPI(`GRAPH_ENGINE_BASE_URL`)를 axios로 호출하고, 응답을 우리 DTO(`GraphResponseDto`/`PathResponseDto`)로 변환해서 반환 (어댑터 패턴 — Neo4j 스키마가 바뀌어도 이 서비스 내부만 수정하면 됨)

## 1. DB 실행 (Docker)

```bash
docker compose up -d
```

## 2. 환경변수 설정

```bash
cp .env.example .env
```

`.env.example`의 기본값이 위 Docker 명령어의 계정 정보와 이미 일치하도록 맞춰져 있음. `GRAPH_ENGINE_BASE_URL`은 Backend 1 FastAPI 엔진 주소(기본 `http://localhost:8000`, uvicorn 기본 포트)이며, 상범님이 다른 포트로 띄우면 이 값도 맞춰야 함.

### 배포(프로덕션) 환경 (인프라팀 확인, 2026-07-22)

`hap-soc-api` EC2는 docker-compose로 nginx + NestJS + Next.js를 함께 띄우고, nginx가 3000번(ALB가 바라보는 유일한 포트)에서 `/api/*`는 NestJS로, 나머지는 Next.js로 라우팅하는 구조로 확정됨. NestJS는 nginx가 3000을 쓰기 때문에 내부 포트를 4000으로 옮긴다 — `PORT` 환경변수만 바꾸면 되고 코드 수정은 필요 없음(`main.ts`가 이미 `process.env.PORT`를 읽음).

실제 배포 시 주입될 값(전부 env var로만 읽으므로 코드 변경 불필요):

| 변수 | 값 | 비고 |
|---|---|---|
| `PORT` | `4000` | nginx가 3000을 점유하므로 내부 포트 변경 |
| `GRAPH_ENGINE_BASE_URL` | `http://10.1.20.20:8000` | hap-soc-graph 사설 IP, localhost 아님 |
| `DB_HOST` | `hap-soc-auth-db` RDS 엔드포인트 | 인프라팀이 실제 값 전달 예정 |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Secrets Manager(`hap-soc-jwt-secret`) | JSON에서 분리 주입 |
| `DB_PASSWORD` | Secrets Manager(`hap-soc-db-secret`) | |

이 값들은 docker-compose 환경변수로 주입될 예정이며, 저장소에는 실제 시크릿 값을 커밋하지 않는다.

## 3. Backend 1 엔진 실행 (그래프 조회 기능에 필요)

`hybrid-attack-pathfinder` 레포(`feature/backend1-neo4j-engine` 브랜치)의 Neo4j 실행/seed 적재/FastAPI 서버 구동 방법은 해당 레포 README를 참고. (로컬 환경마다 Python/pip 실행 방식이 달라질 수 있어 여기엔 구체적인 명령어를 중복 기재하지 않음)

이 엔진이 안 떠 있어도 `auth`/`assets`/`scenarios`/`logs` API는 정상 동작하며, `graph` 관련 API만 503(엔진 연결 불가)을 반환한다.

## 4. 설치 및 실행

```bash
npm install
npm run start:dev
```

`start:dev`는 실행 전에 `npm run seed`가 자동으로 먼저 돈다 (`prestart:dev` 훅). 이미 있는 데이터는 건너뛰므로 매번 실행해도 안전함 — 데모 계정/샘플 자산/시나리오가 항상 보장된 상태로 서버가 뜬다. 시드만 따로 돌리고 싶으면:

```bash
npm run seed
```

기동 후 `http://localhost:3000/api/docs`에서 Swagger UI로 전체 엔드포인트 확인 가능. 앱이 켜지는 시점에 `synchronize: true` 설정으로 엔티티 기준 테이블(users/assets/scenarios/audit_logs)이 자동 생성됨 (발표/개발용 임시 설정 — 운영 전환 시 마이그레이션으로 교체 필요).

### 데모 계정 (`npm run seed` 실행 후)

| 이메일 | 비밀번호 | 역할 |
|---|---|---|
| admin@hap.com | Admin1234! | ADMIN |
| analyst@hap.com | Analyst1234! | ANALYST |
| viewer@hap.com | Viewer1234! | VIEWER |

`GET /logs`(감사 로그)는 ADMIN 전용이라 analyst/viewer 계정으로 호출하면 403이 뜬다 (RBAC 정상 동작 확인용).

### 시드되는 공격 시나리오 (Backend 1 엔진 기준)

Backend 1 엔진이 실제로 서빙하는 5개 시나리오와 ID가 1:1로 맞춰져 있다 (`GET /graph/:scenarioId` 호출 시 엔진에 그대로 전달됨).

| ID | 설명 |
|---|---|
| S1-A | dev-01 Access Key 탈취 → 고객 S3 직접 접근 |
| S1-B | dev-01 Access Key로 Readonly Role Assume → 고객 S3 접근 |
| S2 | 인터넷 노출 ALB → Gitea Pod 경유 → RDS 접근 |
| S3 | 온프레미스 WordPress 키 → 고객 S3 제한 접근 |
| S4 | Gitea Pod IRSA → Secret · RDS 접근 |

(2026-07-23: 상범님 엔진의 GET /scenarios를 직접 curl로 확인해 실제 scenarioId(S1-A~S4)로 재동기화. 이전 라운드의 `scn-*` 이름은 엔진에 없는 ID라 GET /graph/:scenarioId가 전부 404였음.)

## 주요 엔드포인트

| 메서드/경로 | 설명 | 권한 |
|---|---|---|
| POST /api/v1/auth/login | 로그인 (Access/Refresh 토큰 발급) | 전체 |
| POST /api/v1/auth/refresh | Access 토큰 재발급 | 전체 |
| GET /api/v1/auth/me | 내 정보 조회 | 로그인 필요 |
| GET /api/v1/assets | 자산 목록 (필터/페이지네이션) | VIEWER 이상 |
| GET /api/v1/scenarios | 시나리오 목록 | VIEWER 이상 |
| GET /api/v1/graph/:scenarioId | 시나리오별 공격 경로 그래프 | VIEWER 이상 |
| GET /api/v1/graph/paths | 두 자산 간 경로 탐색 | ANALYST 이상 |
| GET /api/v1/logs | 감사 로그 조회 | ADMIN |

## 디렉터리 구조

```
src/
├── auth/          # POST /auth/login, /auth/refresh, GET /auth/me
│   ├── dto/
│   ├── entities/  # User
│   ├── guards/    # JwtAuthGuard, RolesGuard
│   ├── strategies/
│   └── interfaces/
├── graph/         # GET /graph, /graph/:scenarioId, /graph/paths
│   └── dto/       # GraphService가 Backend 1(Neo4j/FastAPI) 결과를 이 DTO들로 변환하는 어댑터
├── assets/        # GET /assets, /assets/:id
│   ├── dto/
│   └── entities/  # Asset
├── scenarios/     # GET /scenarios, /scenarios/:id
│   ├── dto/
│   └── entities/  # Scenario
├── logs/          # GET /logs (ADMIN 전용)
│   ├── dto/
│   └── entities/  # LogEntry
├── database/
│   └── seed.ts    # 데모 데이터 시드 스크립트 (계정/자산/시나리오)
└── common/
    ├── enums/     # Role, AssetType, SensitivityLevel, Environment
    ├── decorators/
    ├── filters/   # HttpExceptionFilter (전역 에러 응답 포맷 + 예외 로깅)
    └── dto/
```

## 알려진 제약 / 다음 단계

- (해결됨, 2026-07-22) `assets` 테이블의 자산 ID를 상범님이 직접 전달한 확정 노드 id 전체 목록 기준으로 맞춤 — `hap-onprem-web`, `hap-gitea-db`, `hap-customer-data-s3`, `pod-gitea-app`. 다만 `hybrid-attack-pathfinder`의 `cypher/01_seed_mvp.cypher` 파일 자체는 아직 이 목록으로 push되지 않은 상태(`rds-postgres-prod` 등 예전 이름으로 남아있음)라, 실제 배포/시연 전 상범님 쪽 push 여부를 다시 확인해야 함. `AssetResponseDto.relatedEdgeCount`/`relatedScenarioIds` 계산 로직 자체는 아직 미구현 (TODO)
- `LogsService.record()` 헬퍼가 아직 어느 컨트롤러에서도 호출되지 않음 — 감사 로그 조회 API는 동작하지만 실제로 로그가 쌓이지는 않음
- 운영 전환 시 `synchronize: true` → TypeORM 마이그레이션으로 교체 필요
- Backend 1 엔진은 임의의 source/target 쌍 탐색을 지원하지 않고 고정된 5개 시나리오만 조회 가능 — `GET /graph/paths`는 쿼리와 일치하는 시나리오가 있을 때만 결과를 반환함
