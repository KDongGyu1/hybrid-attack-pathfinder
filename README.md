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



Neo4j Browser 접속:



http://127.0.0.1:7474



로그인 정보:



ID: neo4j

PW: password123

2\. Cypher 데이터 적재

docker exec hybrid-neo4j cypher-shell -u neo4j -p password123 -f /cypher/00\_reset\_and\_constraints.cypher

docker exec hybrid-neo4j cypher-shell -u neo4j -p password123 -f /cypher/01\_seed\_mvp.cypher

3\. Python 패키지 설치

py -m venv .venv

.\\.venv\\Scripts\\python.exe -m pip install --upgrade pip

.\\.venv\\Scripts\\python.exe -m pip install -r requirements.txt

4\. 공격 경로 탐색 엔진 실행

.\\.venv\\Scripts\\python.exe app\\path\_finder.py



결과 파일:



data/path\_results\_mvp.json

5\. Cytoscape.js 변환 실행

.\\.venv\\Scripts\\python.exe app\\export\_cytoscape.py



결과 파일:



data/cytoscape\_elements\_mvp.json

6\. FastAPI 서버 실행

.\\.venv\\Scripts\\python.exe -m uvicorn app.api\_server:app --reload --host 127.0.0.1 --port 8001



API 문서:



http://127.0.0.1:8001/docs

API 엔드포인트

GET /health

GET /scenarios

GET /attack-paths

GET /attack-paths/{scenarioId}

GET /cytoscape

폴더 구조

hybrid-attack-path-backend1/

├─ app/

│  ├─ path\_finder.py

│  ├─ export\_cytoscape.py

│  └─ api\_server.py

├─ cypher/

│  ├─ 00\_reset\_and\_constraints.cypher

│  └─ 01\_seed\_mvp.cypher

├─ data/

│  ├─ path\_results\_mvp.json

│  └─ cytoscape\_elements\_mvp.json

├─ docker-compose.yml

├─ requirements.txt

├─ .gitignore

└─ README.md

