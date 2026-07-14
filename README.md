# hybrid-attack-pathfinder

**Team redred** — KT tech up 사이버보안 2기 실무 프로젝트

온프레미스+AWS 하이브리드 인프라의 자산·권한 관계를 수집해 Neo4j 그래프로
공격 경로를 분석하는 시스템입니다.

---

## 설계 전제

이번에 만드는 하이브리드 인프라는 실제 서비스가 아니라, 공격 경로와 피해 범위를
분석하는 SOC 시스템이 돌아갈 환경입니다. 표준 보안 통제(IAM 최소권한·MFA·암호화 등)는
갖추되, 업무상 필요한 접근 관계(웹→앱→DB, AssumeRole, IRSA, IAM 키 등) 자체가
공격자에게는 이동 경로가 된다는 전제로 설계합니다. 분석 **대상(Prod)** 과 분석
**시스템(SOC)** 을 별도 VPC로 분리합니다.

대상 환경 컨셉은 **하이브리드 운영 기업**: 온프레미스에 서비스 하나(WordPress),
AWS에 서비스 하나(Gitea)를 운영하며, 데이터·백업을 AWS S3로 중앙화합니다. 온프렘
서비스가 **IAM 액세스 키**로 S3에 백업하는 것이 온프렘↔AWS 연결의 근거이자, 침해 시
"IAM 키 탈취 → 클라우드 데이터 접근"이라는 경계 이동 경로가 됩니다.

## 전체 구조 (2-VPC · 단일 계정 · ap-northeast-2)

| VPC | 역할 | CIDR |
| --- | --- | --- |
| **Prod VPC** | 분석 **대상** 환경 (Gitea/EKS·RDS·S3 등) | `10.0.0.0/16` |
| **SOC VPC** | 분석 **시스템** 인프라 (수집·Neo4j·API·로그) | `10.1.0.0/16` |

두 VPC는 **VPC Peering**으로 연결하며, SOC가 Prod 자산을 수집합니다(API 수집은
IAM 권한 기반, Nmap 스캔은 Peering 경로). 온프레미스(Vagrant, `192.168.0.0/24`)는
VPC가 아닌 별도 환경으로, VPN 없이 **IAM 액세스 키**로만 AWS와 연동합니다.

```
[온프레미스 192.168.0.0/24]                 [AWS 단일 계정 · ap-northeast-2]
 웹 서비스(WordPress, IAM 키) ──S3 백업──▶  ┌ Prod VPC 10.0.0.0/16 (분석 대상)
 DB(MySQL)                                 │   Public(2a/2c): ALB · NAT · IGW
                                            │   Private-App(2a/2c): EKS(Gitea Pod)
                                            │   Private-DB(2a/2c): RDS(PostgreSQL)
                                            │   S3 · ECR · KMS · Secrets Manager · IAM
                                            │            ▲ VPC Peering (SOC가 Prod 수집)
                                            └ SOC VPC 10.1.0.0/16 (분석 시스템)
                                                Public(2a/2c): ALB(대시보드) · NAT
                                                Private-App(2a/2c): 수집·Neo4j·API 서버 3대
                                                Private-DB(2a/2c): RDS(auth)
                                                로그: S3 / CloudWatch
```

각 VPC는 2 AZ(`ap-northeast-2a`/`2c`) × 3계층(Public/Private-App/Private-DB) 구조이며,
DB 서브넷은 외부 라우팅 없이 로컬만 유지합니다.

## 애플리케이션 스택

- **AWS 앱: Gitea (Go)** — 자가호스팅 Git 서비스, PostgreSQL 연결. Docker Hub 이미지를
  ECR로 미러링(Trivy 스캔)한 뒤 EKS가 pull(공급망 보안).
- **온프레미스 앱: WordPress (PHP + MySQL)** — 외부 노출, IAM 키로 S3 백업.
- **시크릿**: Gitea DB 비밀번호 등은 Secrets Manager(KMS 암호화)에 저장하고 IRSA +
  Secrets Store CSI Driver로 취득. SOC 서버는 EC2 인스턴스 역할로 취득.
- **최초 침해 발판**: 앱 취약점이 아니라 **인프라 설정 미스**(노출 IAM 키·SG·IRSA
  과다권한)에서 재현.

## 보안 통제 기준선

- **IAM**: 최소권한. IAM Policy는 그래프 스키마에서 독립 노드(`IAM_POLICY`)로 관리.
- **운영 접근**: SSM Session Manager (Bastion 없음, 인바운드 22 미개방).
- **네트워크**: SG 인바운드 최소화, 계층 간 단방향 접근만 허용.
- **암호화**: 민감 데이터스토어는 고객관리형 CMK 6개로 Prod/SOC 신뢰 경계를 분리
  (`hap-prod-rds-cmk`/`hap-soc-rds-cmk`, `hap-prod-secrets-cmk`/`hap-soc-secrets-cmk`,
  `hap-data-cmk`, `hap-log-cmk`). 그 외는 AWS 관리형 기본 암호화.
- **로그**: 모든 로그의 최종 저장소는 `hap-soc-log-s3` (Object Lock·버전 관리로
  무결성, Lifecycle로 비용 관리). CloudTrail·ALB·Flow Logs는 S3 직행, 앱/DB는
  CloudWatch 경유, 온프렘 로그는 collector까지 에이전트로 전송.

## 침해 시나리오 (참고 — 엔진 케이스 S1~S4)

| ID | 시나리오 | 경로 | 최종 자산 |
| --- | --- | --- | --- |
| **S1** | IAM 계정 탈취 → S3 | 유출 IAM 키 → IAM Policy → `S3ReadOnlyRole` → `hap-customer-data-s3` | S3 |
| **S2** | 퍼블릭 침해 → 내부 DB | Internet → ALB → Gitea(EKS) → RDS | RDS |
| **S3** | 온프레미스 침해 → 클라우드 이동 | 온프렘 웹 침해 → 저장된 IAM 키 탈취 → S3 직접 접근 | S3 |
| **S4** | EKS Pod 침해 → IRSA 상승 | Pod(Gitea) → ServiceAccount → `hap-irsa-gitea-role` → S3/RDS | S3·RDS |

## Terraform 구현 현황

인프라는 `terraform/` 아래 모듈 단위로 구성합니다(`modules/<도메인>/`).

- [x] **1단계** — 기본 구조(`providers.tf`/`versions.tf`/`variables.tf`) + 네트워크
      (`modules/vpc`: VPC 2개, 서브넷 12개, RT, IGW, NAT, VPC Peering)
- [x] **2단계** — Security Group (`modules/sg`)
- [x] **3단계** — KMS(CMK 6개) + Secrets Manager (`modules/kms`, `modules/secrets`)
- [x] **4단계** — RDS 2개, S3 2개 (`modules/rds`, `modules/s3`)
- [x] **5단계** — EKS(클러스터+노드그룹+IRSA), EC2 SOC 3대, ALB 2개
      (`modules/eks`, `modules/ec2_soc`, `modules/alb`)
- [x] **6단계** — ECR (`modules/ecr`)
- [x] **7단계** — 로깅(CloudTrail, VPC Flow Logs, Config, CloudWatch) (`modules/logging`)
- [x] **8단계** — IAM(시나리오용, 취약→교정 2단계 배포) (`modules/iam`, `var.iam_mode`)

Terraform 스코프에서 제외되는 항목: 온프레미스(Vagrant/VirtualBox 별도 구성),
ACM 인증서·도메인(수동 발급, ARN만 변수로 연결), VPN/VGW·Bastion·Redis·ACM
Private CA(폐지/제외).

## 앱 배포 (Gitea on EKS)

Terraform 스코프 밖(K8s 애드온·이미지 미러링·앱 배포)이라 `k8s/`에 별도로 둡니다.
AWS Load Balancer Controller·Secrets Store CSI Driver 설치, ECR 미러링, Gitea
매니페스트 적용까지 순서대로 정리된 안내는 [k8s/README.md](k8s/README.md) 참고.
