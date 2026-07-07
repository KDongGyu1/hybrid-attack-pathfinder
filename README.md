\# Hybrid Attack Path Backend1



하이브리드 공격 경로 탐색 시스템의 Backend 1 모듈입니다.



\## 담당 범위



\- Neo4j 그래프 DB 설계

\- 공격 경로 탐색 엔진

\- Cypher 기반 공격 경로 조회

\- Python 기반 JSON 변환

\- Cytoscape.js 연동용 elements 반환

\- FastAPI 기반 탐색 엔진 API 제공



\## 주요 구성



\- SOC VPC: 수집/탐색/API 시스템 운영 영역

\- Prod VPC: Gitea, RDS PostgreSQL, Redis, ECR, Secrets Manager, S3 등 분석 대상

\- On-Prem: AWS Access Key 탈취 기반 하이브리드 공격 시나리오

\- IAM: IAM User, IAM Role, IAM Policy 독립 노드화

\- EKS: Pod, ServiceAccount, IRSA 기반 공격 경로 표현



\## 주요 공격 경로



1\. On-Prem Admin Server → AWS Access Key → IAM User → IAM Policy → S3

2\. EKS Pod → ServiceAccount → IRSA Role → IAM Policy → Secrets Manager

3\. EKS Pod → ServiceAccount → IRSA Role → Secrets Manager → RDS

4\. Internet → Gitea → RDS



\## 실행 방법



\### 1. Neo4j 실행



```bash

docker compose up -d

