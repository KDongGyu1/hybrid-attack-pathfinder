# hybrid-attack-pathfinder

**Team redred** — KT tech up 사이버보안 2기 실무 프로젝트

온프레미스+AWS 하이브리드 인프라의 자산·권한 관계를 수집해 Neo4j 그래프로
공격 경로를 분석하는 SOC 시스템입니다.

## 구성 요소

| 디렉터리 | 내용 |
| --- | --- |
| [`terraform/`](terraform/README.md) | AWS 인프라(Prod VPC·SOC VPC) 설계 및 Terraform 구현 |
| [`k8s/`](k8s/README.md) | EKS 위 Gitea 배포(애드온·이미지 미러링·매니페스트) |
| [`onprem/`](onprem/README.md) | 온프레미스 랩(Vagrant, WordPress + MySQL) |

각 구성 요소의 상세 설계, 구조, 사용법은 위 링크의 README를 참고하세요.
