# hybrid-attack-pathfinder

**Team redred** — KT tech up 사이버보안 2기 실무 프로젝트

온프레미스+AWS 하이브리드 인프라의 자산·권한 관계를 수집해 Neo4j 그래프로
공격 경로를 분석하는 SOC 시스템입니다.

## 시스템 구성

```
Frontend (Next.js)  →  Backend2 API (NestJS)  →  Backend1 엔진 (Neo4j + FastAPI)
                              │
                        PostgreSQL (계정·자산·시나리오·감사로그)
```

- **Frontend**: 로그인, 자산 목록, 감사 로그, 공격 경로 그래프 시각화(Cytoscape.js)
- **Backend2**: 인증/인가(JWT+RBAC), 자산·시나리오·감사로그 조회(PostgreSQL), Backend1 결과를 REST 계약으로 변환하는 어댑터
- **Backend1**: 인프라 자산·권한 관계를 Neo4j 그래프로 모델링하고, 공격 경로 탐색·탐지룰·리스크 스코어링 제공
- **Collector**: SOC 서버(`hap-soc-collector`)에서 AWS 자산 인벤토리, Trivy 이미지 스캔, Scout Suite 계정 진단을 수집해 Backend1 그래프의 시드 데이터로 공급
- **Infra**: Terraform으로 Prod/SOC 2-VPC AWS 인프라 구성, EKS 위 Gitea(Prod 대상 앱) 배포, 온프레미스 WordPress 랩(Vagrant)

## 배포 구조 (`hap-soc-api` EC2)

```
ALB(443, hap-soc.kro.kr) → nginx:3000 → /api/*  → NestJS(내부 4000)
                                       → 그 외    → Next.js(내부 3001)
                                                        │
                                        NestJS → Backend1 FastAPI(hap-soc-graph, 8000)
```

`docker-compose.prod.yml` + `nginx/nginx.conf`로 nginx·NestJS·Next.js 3개 컨테이너를 함께 기동합니다.

## 구성 요소

| 디렉터리 | 설명 | 상태 |
| --- | --- | --- |
| [`terraform/`](terraform/README.md) | AWS 인프라(Prod VPC·SOC VPC) 설계 및 Terraform 구현 | main |
| [`k8s/`](k8s/README.md) | EKS 위 Gitea 배포(애드온·이미지 미러링·매니페스트) | main |
| [`onprem/`](onprem/README.md) | 온프레미스 랩(Vagrant, WordPress + MySQL) | main |
| [`collector/`](collector/READMA.md) | SOC 서버 자산·취약점 스캔 결과 수집 도구 | main |
| [`hybrid-attack-path-backend/`](hybrid-attack-path-backend/README.md) | Backend2 REST API 서버 (NestJS) | main |
| [`hybrid-attack-path-frontend/`](hybrid-attack-path-frontend/README.md) | 웹 대시보드 (Next.js) | main |
| `feature/backend1-neo4j-engine` (브랜치) | Backend1 그래프 탐색 엔진 (Neo4j + FastAPI) — 공격 경로/탐지룰/리스크 스코어링. 담당자가 별도로 main에 병합 예정 | 별도 브랜치 |

각 구성 요소의 상세 설계, 구조, 사용법은 위 링크의 README를 참고하세요.
