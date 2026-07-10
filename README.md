# Hybrid Attack Path Backend1

하이브리드 공격 경로 탐색 시스템의 Backend1 모듈입니다.

Backend1은 하이브리드 인프라 환경의 자산과 권한 관계를 Neo4j 그래프 DB로 모델링하고, Cypher 쿼리를 통해 공격자가 이동 가능한 경로를 탐색하는 역할을 담당합니다.

---

## 담당 범위

* Neo4j 그래프 DB 설계
* 하이브리드 인프라 자산 노드/관계 모델링
* 대표 침해 시나리오 기반 seed 데이터 구성
* Cypher 기반 공격 경로 탐색 쿼리 작성
* 공격 경로 탐색 결과 검증

---

## 주요 구성

### 분석 대상 인프라

* **SOC VPC**

  * 수집/탐색/API 시스템 운영 영역
  * Neo4j 기반 공격 경로 그래프 DB
  * Backend1 탐색 엔진

* **Prod VPC**

  * Public Subnet
  * Private App Subnet
  * Private DB Subnet
  * Public Web ALB
  * EKS Cluster
  * RDS PostgreSQL
  * S3 Bucket
  * Secrets Manager
  * ECR Repository
  * CloudWatch Log
  * KMS Key

* **On-Prem**

  * WordPress Server
  * MySQL Database
  * IAM Access Key

### 권한 및 실행 환경

* **EKS**

  * Pod
  * ServiceAccount
  * IRSA 기반 IAM Role 연결

* **IAM**

  * IAM User
  * IAM Role
  * IAM Policy
  * IAM Access Key
  * S3 접근 권한
  * Secrets Manager 조회 권한

### 보안 분석 요소

* 인터넷 노출 여부
* 온프레미스 서버 침해 여부
* IAM Access Key 탈취 가능성
* 온프레미스에서 AWS로의 경계 이동 가능성
* Kubernetes ServiceAccount 사용 관계
* IRSA 기반 IAM Role 연결 관계
* IAM Policy 권한 관계
* S3, RDS, Secrets Manager 등 민감 자산 접근 가능성
* Finding 기반 보안 설정 오류 표현

---

## 주요 공격 경로

본 MVP에서는 다음 공격 경로를 Neo4j 그래프와 Cypher 쿼리로 검증합니다.

1. **S1: IAM Access Key 탈취 → S3 고객 데이터 접근**

```text
IAM Access Key → IAM User → IAM Policy → S3Bucket
```

확정 리소스 기준 경로:

```text
hap-onprem-access-key → hap-dev-01-user → hap-s3-access-policy → hap-customer-data-s3
```

2. **S3: On-Prem WordPress 침해 → IAM Access Key 탈취 → S3 고객 데이터 접근**

```text
On-Prem WordPress → IAM Access Key → IAM User → IAM Policy → S3Bucket
```

확정 리소스 기준 경로:

```text
hap-onprem-web → hap-onprem-access-key → hap-dev-01-user → hap-s3-access-policy → hap-customer-data-s3
```

3. **S4: EKS ServiceAccount 권한 탈취 → IRSA Role → S3 고객 데이터 접근**

```text
Internet → ALB → Pod → ServiceAccount → IAMRole → IAMPolicy → S3Bucket
```

확정 리소스 기준 경로:

```text
Internet → Public Web ALB → Pod → gitea-sa → hap-irsa-gitea-role → hap-gitea-role-policy → hap-customer-data-s3
```

4. **외부 진입점 → 내부 워크로드 → RDS 접근**

```text
Internet → ALB → Pod → RDS
```

확정 리소스 기준 경로:

```text
Internet → Public Web ALB → Pod → hap-gitea-db
```

5. **Secrets Manager 권한 과다 → DB Credential 탈취 → RDS 접근**

```text
Pod → ServiceAccount → IAMRole → IAMPolicy → SecretsManager → RDS
```

확정 리소스 기준 경로:

```text
Pod → gitea-sa → hap-irsa-gitea-role → hap-gitea-role-policy → SecretsManager → hap-gitea-db
```

---

## 확정 리소스 ID 기준

동규님 자산 수집 JSON과 Backend1 그래프 노드 매칭을 위해 seed 데이터의 노드 id는 아래 확정 이름을 기준으로 사용합니다.

| 자산                     | 확정 id                 |
| ---------------------- | --------------------- |
| IAM User               | hap-dev-01-user       |
| IAM Policy             | hap-s3-access-policy  |
| IAM Role               | hap-s3-readonly-role  |
| IRSA Role              | hap-irsa-gitea-role   |
| IRSA Policy            | hap-gitea-role-policy |
| ServiceAccount         | gitea-sa              |
| RDS                    | hap-gitea-db          |
| S3                     | hap-customer-data-s3  |
| Prod VPC               | hap-prod-vpc          |
| SOC VPC                | hap-soc-vpc           |
| On-Prem Web            | hap-onprem-web        |
| On-Prem DB             | hap-onprem-db         |
| On-Prem IAM Access Key | hap-onprem-access-key |

---

## 폴더 구조

```text
hybrid-attack-path-backend1/
├─ scripts/
│  ├─ seed.cypher
│  └─ attack-path-queries.cypher
├─ docs/
│  └─ backend1-neo4j-design.md
└─ README.md
```

---

## 실행 방법

### 1. Neo4j 컨테이너 실행

Neo4j 컨테이너가 없다면 아래 명령어로 실행합니다.

```powershell
docker run -d `
  --name hybrid-neo4j `
  -p 7474:7474 `
  -p 7687:7687 `
  -e NEO4J_AUTH=neo4j/password1234 `
  neo4j:5
```

이미 컨테이너가 있다면 아래 명령어로 실행합니다.

```powershell
docker start hybrid-neo4j
```

컨테이너 실행 여부 확인:

```powershell
docker ps
```

---

### 2. Seed 데이터 적재

`scripts/seed.cypher` 파일을 Neo4j 컨테이너 내부로 복사합니다.

```powershell
docker cp .\scripts\seed.cypher hybrid-neo4j:/seed.cypher
```

Neo4j에 seed 데이터를 적재합니다.

```powershell
docker exec -it hybrid-neo4j cypher-shell -u neo4j -p password1234 -f /seed.cypher
```

---

### 3. Neo4j Browser 접속

브라우저에서 아래 주소로 접속합니다.

```text
http://localhost:7474
```

로그인 정보:

```text
Username: neo4j
Password: password1234
```

---

### 4. 전체 그래프 확인

Neo4j Browser에서 아래 쿼리를 실행합니다.

```cypher
MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 50;
```

---

### 5. 공격 경로 탐색 쿼리 실행

#### On-Prem WordPress에서 S3 Bucket까지의 공격 경로

```cypher
MATCH path = (start {id: "hap-onprem-web"})-[r*1..8]->(target {id: "hap-customer-data-s3"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "CONNECTS_TO",
    "HAS_ACCESS_KEY",
    "AUTHENTICATES_AS",
    "HAS_PERMISSION",
    "CAN_ACCESS"
  ]
)
RETURN path;
```

예상 경로:

```text
hap-onprem-web → hap-onprem-access-key → hap-dev-01-user → hap-s3-access-policy → hap-customer-data-s3
```

---

#### IAM Access Key에서 S3 Bucket까지의 공격 경로

```cypher
MATCH path = (start {id: "hap-onprem-access-key"})-[r*1..8]->(target {id: "hap-customer-data-s3"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "AUTHENTICATES_AS",
    "HAS_PERMISSION",
    "CAN_ACCESS"
  ]
)
RETURN path;
```

예상 경로:

```text
hap-onprem-access-key → hap-dev-01-user → hap-s3-access-policy → hap-customer-data-s3
```

---

#### Internet에서 S3 Bucket까지의 공격 경로

```cypher
MATCH path = (start {id: "internet"})-[r*1..8]->(target {id: "hap-customer-data-s3"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "USES_SERVICE_ACCOUNT",
    "IRSA_LINKED_TO",
    "HAS_PERMISSION",
    "CAN_ACCESS"
  ]
)
RETURN path;
```

예상 경로:

```text
Internet → Public Web ALB → Pod → gitea-sa → hap-irsa-gitea-role → hap-gitea-role-policy → hap-customer-data-s3
```

---

#### Internet에서 RDS까지의 공격 경로

```cypher
MATCH path = (start {id: "internet"})-[r*1..8]->(target {id: "hap-gitea-db"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "CONNECTS_TO"
  ]
)
RETURN path;
```

예상 경로:

```text
Internet → Public Web ALB → Pod → hap-gitea-db
```

---

#### Pod에서 Secrets Manager를 거쳐 RDS까지의 공격 경로

```cypher
MATCH path = (start {id: "pod-gitea-app"})-[r*1..8]->(target {id: "hap-gitea-db"})
WHERE ALL(rel IN relationships(path)
  WHERE type(rel) IN [
    "USES_SERVICE_ACCOUNT",
    "IRSA_LINKED_TO",
    "HAS_PERMISSION",
    "CAN_ACCESS",
    "CAN_ACCESS_SECRET",
    "CONNECTS_TO"
  ]
)
RETURN path;
```

예상 경로:

```text
pod-gitea-app → gitea-sa → hap-irsa-gitea-role → hap-gitea-role-policy → SecretsManager → hap-gitea-db
```

---

## 주요 노드 타입

| Node Type      | 설명                              |
| -------------- | ------------------------------- |
| Internet       | 외부 공격자 또는 외부 접근 지점              |
| VPC            | 클라우드 네트워크 단위                    |
| Subnet         | Public/Private 서브넷              |
| ALB            | 외부 트래픽 진입점                      |
| EKSCluster     | Kubernetes 클러스터                 |
| Pod            | 애플리케이션 실행 단위                    |
| ServiceAccount | Pod가 사용하는 Kubernetes 권한 주체      |
| IAMUser        | AWS IAM 사용자                     |
| IAMRole        | AWS 권한 위임 역할                    |
| IAMPolicy      | IAM Role 또는 IAM User에 연결된 권한 정책 |
| IAMAccessKey   | AWS API 호출에 사용되는 Access Key     |
| S3Bucket       | 객체 저장소                          |
| RDS            | 관계형 데이터베이스                      |
| SecretsManager | 민감정보 저장소                        |
| KMSKey         | 암호화 키                           |
| ECRRepository  | 컨테이너 이미지 저장소                    |
| CloudWatchLog  | 로그 저장소                          |
| OnPremWeb      | 온프레미스 웹 서버                      |
| OnPremDB       | 온프레미스 데이터베이스                    |
| Finding        | 취약점 또는 보안 설정 오류                 |

---

## 주요 관계 타입

| Relation Type        | 설명                             |
| -------------------- | ------------------------------ |
| CONTAINS             | 상위 자산이 하위 자산을 포함               |
| EXPOSED_TO_INTERNET  | 인터넷에서 접근 가능한 자산                |
| ALLOWS_TRAFFIC       | 네트워크 트래픽 허용 관계                 |
| CAN_MOVE_TO          | 공격자가 이동 가능한 경로                 |
| CONNECTS_TO          | 애플리케이션 또는 자산 간 연결 관계           |
| RUNS_ON              | Pod가 EKSCluster에서 실행됨          |
| USES_SERVICE_ACCOUNT | Pod가 ServiceAccount를 사용        |
| IRSA_LINKED_TO       | ServiceAccount가 IRSA Role과 연결됨 |
| HAS_ACCESS_KEY       | 서버 또는 자산이 IAM Access Key를 보유   |
| AUTHENTICATES_AS     | Access Key가 IAM User로 인증됨      |
| HAS_PERMISSION       | IAM 주체가 IAM Policy를 통해 권한을 가짐  |
| CAN_ACCESS           | 특정 자산에 접근 가능                   |
| CAN_ACCESS_SECRET    | Secrets Manager Secret 조회 가능   |
| ENCRYPTED_BY         | KMS Key로 암호화됨                  |
| PULLS_IMAGE_FROM     | 컨테이너 이미지를 ECR에서 가져옴            |
| LOGS_TO              | 로그를 CloudWatch로 전송             |
| HAS_FINDING          | 자산에 취약점 또는 설정 오류 존재            |

---

## 검증 결과

Neo4j에 seed 데이터를 적재한 뒤, Cypher 기반 공격 경로 탐색 쿼리를 실행하여 다음 경로가 정상적으로 도출되는 것을 확인했습니다.

* On-Prem WordPress → IAM Access Key → IAM User → IAM Policy → S3Bucket
* IAM Access Key → IAM User → IAM Policy → S3Bucket
* Internet → ALB → Pod → ServiceAccount → IRSA Role → IAMPolicy → S3Bucket
* Internet → ALB → Pod → RDS
* Pod → ServiceAccount → IRSA Role → IAMPolicy → SecretsManager → RDS

이를 통해 온프레미스 서버 침해, IAM Access Key 탈취, Kubernetes ServiceAccount, AWS IAM 권한, 민감 데이터 접근 관계를 하나의 그래프로 연결하고, Cypher 쿼리를 통해 하이브리드 인프라 환경의 공격 가능 경로를 탐색할 수 있음을 검증했습니다.

---

## 향후 확장 방향

* Python 기반 공격 경로 결과 JSON 변환
* FastAPI 기반 탐색 API 제공
* Cytoscape.js 연동용 elements 반환
* 위험도 점수 기반 경로 정렬
* 실제 AWS/EKS/On-Prem 자산 수집 데이터 연동
* 동규님 자산 수집 JSON의 node type, relation type enum과 Backend1 그래프 스키마 통일
