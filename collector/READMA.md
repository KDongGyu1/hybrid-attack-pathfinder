 hap-soc-collector 스캔·자산 조회 결과

**수집 일시**: 2026-07-23
**수집자**: hap-soc-collector (i-0600b4fe907001fa5)
**계정**: AWS 893961164525 (ap-northeast-2)
**IAM Instance Profile**: hap-soc-collector-role

---

## 디렉터리 구조

    collector-outputs/
    ├── README.md         본 파일 (전체 요약)
    ├── assets/           AWS 자산 인벤토리 (8종 60개)
    ├── trivy/            Trivy 컨테이너 이미지 스캔 (188개 취약점)
    └── scoutsuite/       Scout Suite AWS 계정 진단 (357개 Finding)

---

## 1. AWS 자산 인벤토리

| 자산 종류 | 개수 | 파일 |
|---|---:|---|
| EC2 인스턴스 | 4 | assets/ec2-instances.json |
| IAM 사용자 | 4 | assets/iam-users.json |
| IAM 역할 | 22 | assets/iam-roles.json |
| S3 버킷 | 3 | assets/s3-buckets.json |
| RDS 인스턴스 | 2 | assets/rds-instances.json |
| Secrets Manager | 4 | assets/secrets.json |
| KMS 키 | 15 | assets/kms-keys.json |
| Security Group | 10 | assets/security-groups.json |

### EC2 인스턴스
- i-09551511ff953244a: hap-nodegroup-node (t3.small)
- i-005fddec50b349732: hap-soc-api (t3.small)
- i-0600b4fe907001fa5: hap-soc-collector (t3.small)
- i-05ad2262c2b49553e: hap-soc-graph (t3.small)

### S3 버킷 (자산 인벤토리 등급 매핑)
- hap-customer-data-s3 (Restricted, Prod)
- hap-soc-log-s3 (Restricted, SOC)
- hap-soc-alb-log-s3 (Confidential, SOC)

### RDS 인스턴스
- hap-gitea-db: postgres (Prod)
- hap-soc-auth-db: postgres (SOC, Restricted)

### IAM 사용자
- admin
- hap-dev-01-user (S1 시나리오 관련)
- hap-onprem-web-user (S3 시나리오 관련)
- hap-onprem-db-user (S3 시나리오 관련)

### Secrets Manager
- hap-db-secret (Prod, Gitea DB)
- hap-soc-db-secret (SOC)
- hap-soc-jwt-secret (SOC, JWT)
- hap-soc-neo4j-secret (SOC, Neo4j)

---

## 2. Trivy 컨테이너 이미지 스캔

**대상**: debian:11 (샘플 이미지)
**결과 파일**: trivy/debian-11.json
**총 취약점**: **188개**

| Severity | 개수 |
|---|---:|
| CRITICAL | 6 |
| HIGH | 19 |
| MEDIUM | 60 |
| LOW | 94 |
| UNKNOWN | 9 |

**상위 HIGH 발견**:
- CVE-2022-3715 (bash): 힙 오버플로우
- CVE-2026-53615 (bsdutils, libblkid1): Integer Overflow
- CVE-2026-41992 (gzip): 글로벌 버퍼 오버플로우
- CVE-2026-54369 (libacl1): Symlink 권한 상승

---

## 3. Scout Suite AWS 계정 진단

**대상**: AWS 계정 893961164525
**결과 파일**:
- HTML 리포트: scoutsuite/aws-893961164525.html
- JSON 원본: scoutsuite/scoutsuite-results/scoutsuite_results_aws-893961164525.js

**총 Finding**: **357개** (danger 17 + warning 340)

### 서비스별 Finding

| 서비스 | 개수 |
|---|---:|
| VPC | 213 |
| EC2 | 92 |
| Config | 16 |
| IAM | 14 |
| S3 | 10 |
| ELBv2 | 5 |
| RDS | 4 |
| CloudTrail | 3 |

### danger 등급 발견 (팀 시나리오와 정합)

**IAM 관련 (S1, S3, S4 시나리오)**
- iam-assume-role-lacks-external-id-and-mfa (4건)
  → Cross-Account AssumeRole 시 External ID와 MFA 부재
  → S1 hap-s3-readonly-role Trust Policy 취약 버전과 일치
- iam-managed-policy-allows-full-privileges (1건)
  → Managed Policy가 전체 권한 부여
  → S1 hap-s3-access-policy 취약 버전 (s3:* + Resource *)과 일치
- iam-password-policy-* (5건): 패스워드 정책 미흡

**ELBv2 (S2 시나리오 - 인터넷→Gitea)**
- elbv2-listener-allowing-cleartext (1건)
  → ALB가 HTTP 평문 통신 허용
  → S2 시나리오 인터넷 노출 경로와 일치
- elbv2-http-request-smuggling (2건)

**RDS**
- rds-instance-single-az (2건)

**CloudTrail**
- cloudtrail-no-log-file-validation (1건)

### warning 등급 (상위 5개)
- vpc-subnet-with-allow-all-egress-acls (63건)
- vpc-subnet-with-allow-all-ingress-acls (63건)
- vpc-subnet-without-flow-log (51건)
- ec2-default-security-group-with-rules (36건)
- ec2-security-group-opens-all-ports (20건)

---

## 4. 스캔 명령 (재현용)

```bash
# 작업 디렉터리
mkdir -p collector-outputs/{trivy,scoutsuite,assets}

# 1. 자산 조회
cd collector-outputs/assets
aws ec2 describe-instances --region ap-northeast-2 > ec2-instances.json
aws iam list-users > iam-users.json
aws iam list-roles > iam-roles.json
aws s3api list-buckets > s3-buckets.json
aws rds describe-db-instances --region ap-northeast-2 > rds-instances.json
aws secretsmanager list-secrets --region ap-northeast-2 > secrets.json
aws kms list-keys --region ap-northeast-2 > kms-keys.json
aws ec2 describe-security-groups --region ap-northeast-2 > security-groups.json

# 2. Trivy 컨테이너 이미지 스캔
cd ../trivy
trivy image debian:11 -f json -o debian-11.json

# 3. Scout Suite AWS 계정 진단
cd ../scoutsuite
scout aws --no-browser --report-dir .
## 5. 팀 시나리오와의 정합성

Scout Suite 스캔 결과가 팀 시나리오 문서 v1.1의 위험 지점을 실제로 탐지함.

### 시나리오별 매핑

**S1 시나리오 (dev-01 사용자 -> S3)**

- iam-assume-role-lacks-external-id-and-mfa (4건)
  Cross-Account AssumeRole Policy에 External ID와 MFA 부재
  -> S1 hap-s3-readonly-role Trust Policy 취약 버전과 일치
- iam-managed-policy-allows-full-privileges (1건)
  Managed Policy Allows All Actions
  -> S1 hap-s3-access-policy 취약 버전 (s3:* + Resource *)과 일치

**S2 시나리오 (인터넷 -> Gitea Pod)**

- elbv2-listener-allowing-cleartext (1건)
  Load Balancer Allowing Clear Text (HTTP) Communication
  -> S2 시나리오 인터넷 노출 경로와 일치
- elbv2-http-request-smuggling (2건)
  Drop Invalid Header Fields Disabled

**S3 시나리오 (온프렘 -> S3)**

- S3 관련 warning 10건
  버킷 정책 및 접근 제어 이슈

**CloudTrail 및 모니터링**

- cloudtrail-no-log-file-validation (1건)
  로그 무결성 검증 미설정
- vpc-subnet-without-flow-log (51건)
  Flow Log 미설정 서브넷

이는 collector의 스캔 결과가 팀이 시각화하는 공격 경로와 실제로 일치함을 보여주는 강력한 근거입니다.

---

## 6. 후속 과제

본 collector는 오늘 시점에서 도구 설치, 배치 스캔, 자산 조회까지 완료했습니다.
다음 항목은 (0)-3 페인포인트 문서 9.4절에 후속 과제로 정의되어 있습니다.

1. 실시간 이벤트 스트리밍 파이프라인 (Kinesis + Lambda -> Neo4j)
2. Trivy 및 Scout Suite 결과의 graph 실시간 push
3. CloudTrail 핵심 이벤트 실시간 반영
4. 멀티 클라우드 (Azure, GCP) 자산 수집 어댑터
5. Flow Log 및 ALB 로그 정기 배치 파싱

---

## 7. 참고 문서

- (0)-3 페인포인트 문서 (김동규)
- 자산 인벤토리 및 민감도 등급 매핑 v6 (윤지수)
- 시나리오별 IAM 리소스 명세서 v1 (김민아)
- 침해 시나리오 및 케이스 스터디 v1.1 (김상범)
- 자산 수집 범위 설계 및 정의 v1 (김동규)
[root@ip-10-1-20-10 scoutsuite]# sed -i 's|scout aws --no-browser --report-dir .$|scout aws --no-browser --report-dir .\n```|' /root/collector-outputs/README.md
[root@ip-10-1-20-10 scoutsuite]# 
[root@ip-10-1-20-10 scoutsuite]# # 확인
[root@ip-10-1-20-10 scoutsuite]# sed -n '/^# 3. Scout Suite/,/^## 5. 팀/p' /root/collector-outputs/README.md | head -20
# 3. Scout Suite AWS 계정 진단
cd ../scoutsuite
scout aws --no-browser --report-dir .
```
## 5. 팀 시나리오와의 정합성
[root@ip-10-1-20-10 scoutsuite]# cat /root/collector-outputs/README.md
# hap-soc-collector 스캔·자산 조회 결과

**수집 일시**: 2026-07-23
**수집자**: hap-soc-collector (i-0600b4fe907001fa5)
**계정**: AWS 893961164525 (ap-northeast-2)
**IAM Instance Profile**: hap-soc-collector-role

---

## 디렉터리 구조

    collector-outputs/
    ├── README.md         본 파일 (전체 요약)
    ├── assets/           AWS 자산 인벤토리 (8종 60개)
    ├── trivy/            Trivy 컨테이너 이미지 스캔 (188개 취약점)
    └── scoutsuite/       Scout Suite AWS 계정 진단 (357개 Finding)

---

## 1. AWS 자산 인벤토리

| 자산 종류 | 개수 | 파일 |
|---|---:|---|
| EC2 인스턴스 | 4 | assets/ec2-instances.json |
| IAM 사용자 | 4 | assets/iam-users.json |
| IAM 역할 | 22 | assets/iam-roles.json |
| S3 버킷 | 3 | assets/s3-buckets.json |
| RDS 인스턴스 | 2 | assets/rds-instances.json |
| Secrets Manager | 4 | assets/secrets.json |
| KMS 키 | 15 | assets/kms-keys.json |
| Security Group | 10 | assets/security-groups.json |

### EC2 인스턴스
- i-09551511ff953244a: hap-nodegroup-node (t3.small)
- i-005fddec50b349732: hap-soc-api (t3.small)
- i-0600b4fe907001fa5: hap-soc-collector (t3.small)
- i-05ad2262c2b49553e: hap-soc-graph (t3.small)

### S3 버킷 (자산 인벤토리 등급 매핑)
- hap-customer-data-s3 (Restricted, Prod)
- hap-soc-log-s3 (Restricted, SOC)
- hap-soc-alb-log-s3 (Confidential, SOC)

### RDS 인스턴스
- hap-gitea-db: postgres (Prod)
- hap-soc-auth-db: postgres (SOC, Restricted)

### IAM 사용자
- admin
- hap-dev-01-user (S1 시나리오 관련)
- hap-onprem-web-user (S3 시나리오 관련)
- hap-onprem-db-user (S3 시나리오 관련)

### Secrets Manager
- hap-db-secret (Prod, Gitea DB)
- hap-soc-db-secret (SOC)
- hap-soc-jwt-secret (SOC, JWT)
- hap-soc-neo4j-secret (SOC, Neo4j)

---

## 2. Trivy 컨테이너 이미지 스캔

**대상**: debian:11 (샘플 이미지)
**결과 파일**: trivy/debian-11.json
**총 취약점**: **188개**

| Severity | 개수 |
|---|---:|
| CRITICAL | 6 |
| HIGH | 19 |
| MEDIUM | 60 |
| LOW | 94 |
| UNKNOWN | 9 |

**상위 HIGH 발견**:
- CVE-2022-3715 (bash): 힙 오버플로우
- CVE-2026-53615 (bsdutils, libblkid1): Integer Overflow
- CVE-2026-41992 (gzip): 글로벌 버퍼 오버플로우
- CVE-2026-54369 (libacl1): Symlink 권한 상승

---

## 3. Scout Suite AWS 계정 진단

**대상**: AWS 계정 893961164525
**결과 파일**:
- HTML 리포트: scoutsuite/aws-893961164525.html
- JSON 원본: scoutsuite/scoutsuite-results/scoutsuite_results_aws-893961164525.js

**총 Finding**: **357개** (danger 17 + warning 340)

### 서비스별 Finding

| 서비스 | 개수 |
|---|---:|
| VPC | 213 |
| EC2 | 92 |
| Config | 16 |
| IAM | 14 |
| S3 | 10 |
| ELBv2 | 5 |
| RDS | 4 |
| CloudTrail | 3 |

### danger 등급 발견 (팀 시나리오와 정합)

**IAM 관련 (S1, S3, S4 시나리오)**
- iam-assume-role-lacks-external-id-and-mfa (4건)
  → Cross-Account AssumeRole 시 External ID와 MFA 부재
  → S1 hap-s3-readonly-role Trust Policy 취약 버전과 일치
- iam-managed-policy-allows-full-privileges (1건)
  → Managed Policy가 전체 권한 부여
  → S1 hap-s3-access-policy 취약 버전 (s3:* + Resource *)과 일치
- iam-password-policy-* (5건): 패스워드 정책 미흡

**ELBv2 (S2 시나리오 - 인터넷→Gitea)**
- elbv2-listener-allowing-cleartext (1건)
  → ALB가 HTTP 평문 통신 허용
  → S2 시나리오 인터넷 노출 경로와 일치
- elbv2-http-request-smuggling (2건)

**RDS**
- rds-instance-single-az (2건)

**CloudTrail**
- cloudtrail-no-log-file-validation (1건)

### warning 등급 (상위 5개)
- vpc-subnet-with-allow-all-egress-acls (63건)
- vpc-subnet-with-allow-all-ingress-acls (63건)
- vpc-subnet-without-flow-log (51건)
- ec2-default-security-group-with-rules (36건)
- ec2-security-group-opens-all-ports (20건)

---

## 4. 스캔 명령 (재현용)

```bash
# 작업 디렉터리
mkdir -p collector-outputs/{trivy,scoutsuite,assets}

# 1. 자산 조회
cd collector-outputs/assets
aws ec2 describe-instances --region ap-northeast-2 > ec2-instances.json
aws iam list-users > iam-users.json
aws iam list-roles > iam-roles.json
aws s3api list-buckets > s3-buckets.json
aws rds describe-db-instances --region ap-northeast-2 > rds-instances.json
aws secretsmanager list-secrets --region ap-northeast-2 > secrets.json
aws kms list-keys --region ap-northeast-2 > kms-keys.json
aws ec2 describe-security-groups --region ap-northeast-2 > security-groups.json

# 2. Trivy 컨테이너 이미지 스캔
cd ../trivy
trivy image debian:11 -f json -o debian-11.json

# 3. Scout Suite AWS 계정 진단
cd ../scoutsuite
scout aws --no-browser --report-dir .
```
## 5. 팀 시나리오와의 정합성

Scout Suite 스캔 결과가 팀 시나리오 문서 v1.1의 위험 지점을 실제로 탐지함.

### 시나리오별 매핑

**S1 시나리오 (dev-01 사용자 -> S3)**

- iam-assume-role-lacks-external-id-and-mfa (4건)
  Cross-Account AssumeRole Policy에 External ID와 MFA 부재
  -> S1 hap-s3-readonly-role Trust Policy 취약 버전과 일치
- iam-managed-policy-allows-full-privileges (1건)
  Managed Policy Allows All Actions
  -> S1 hap-s3-access-policy 취약 버전 (s3:* + Resource *)과 일치

**S2 시나리오 (인터넷 -> Gitea Pod)**

- elbv2-listener-allowing-cleartext (1건)
  Load Balancer Allowing Clear Text (HTTP) Communication
  -> S2 시나리오 인터넷 노출 경로와 일치
- elbv2-http-request-smuggling (2건)
  Drop Invalid Header Fields Disabled

**S3 시나리오 (온프렘 -> S3)**

- S3 관련 warning 10건
  버킷 정책 및 접근 제어 이슈

**CloudTrail 및 모니터링**

- cloudtrail-no-log-file-validation (1건)
  로그 무결성 검증 미설정
- vpc-subnet-without-flow-log (51건)
  Flow Log 미설정 서브넷

이는 collector의 스캔 결과가 팀이 시각화하는 공격 경로와 실제로 일치함을 보여주는 강력한 근거입니다.

---

## 6. 후속 과제

본 collector는 오늘 시점에서 도구 설치, 배치 스캔, 자산 조회까지 완료했습니다.
다음 항목은 (0)-3 페인포인트 문서 9.4절에 후속 과제로 정의되어 있습니다.

1. 실시간 이벤트 스트리밍 파이프라인 (Kinesis + Lambda -> Neo4j)
2. Trivy 및 Scout Suite 결과의 graph 실시간 push
3. CloudTrail 핵심 이벤트 실시간 반영
4. 멀티 클라우드 (Azure, GCP) 자산 수집 어댑터
5. Flow Log 및 ALB 로그 정기 배치 파싱

---

## 7. 참고 문서

- (0)-3 페인포인트 문서 (김동규)
- 자산 인벤토리 및 민감도 등급 매핑 v6 (윤지수)
- 시나리오별 IAM 리소스 명세서 v1 (김민아)
- 침해 시나리오 및 케이스 스터디 v1.1 (김상범)
- 자산 수집 범위 설계 및 정의 v1 (김동규)