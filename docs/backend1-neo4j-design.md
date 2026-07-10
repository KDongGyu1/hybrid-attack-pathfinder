\# Backend1 Neo4j Graph DB 설계 및 Cypher 기반 공격 경로 탐색



\## 1. 담당 범위



Backend1은 하이브리드 공격 경로 탐색 시스템에서 그래프 DB 설계와 공격 경로 탐색 로직을 담당한다.



담당 범위는 다음과 같다.



\- Neo4j 기반 그래프 데이터 모델 설계

\- 하이브리드 인프라 자산의 노드 및 관계 정의

\- 대표 침해 시나리오 기반 seed 데이터 구성

\- Cypher 기반 공격 경로 탐색 쿼리 작성

\- 탐색 결과 검증



본 단계에서는 FastAPI 연동이나 프론트엔드 시각화 구현은 포함하지 않고, Neo4j 내부에서 공격 경로가 실제로 탐색되는지 검증하는 것을 목표로 한다.



\---



\## 2. 그래프 모델링 방향



본 시스템은 클라우드, Kubernetes, IAM, 데이터 저장소 자산을 그래프 구조로 모델링한다.



일반적인 자산 목록 방식은 개별 자산의 존재 여부만 확인할 수 있지만, 그래프 기반 모델은 자산 간 연결 관계와 권한 흐름을 함께 표현할 수 있다.



따라서 공격자가 외부 진입점에서 시작해 어떤 네트워크 경로, 권한 경로, 데이터 접근 경로를 통해 중요 자산까지 도달할 수 있는지 분석할 수 있다.



본 MVP에서는 다음 세 가지 흐름을 중심으로 그래프를 구성하였다.



1\. 네트워크 노출 경로

2\. Kubernetes ServiceAccount 기반 권한 경로

3\. AWS IAM Policy 기반 민감 데이터 접근 경로



\---



\## 3. 주요 노드 타입



| Node Type | 설명 |

|---|---|

| Internet | 외부 공격자 또는 외부 접근 지점 |

| VPC | 클라우드 네트워크 단위 |

| Subnet | Public/Private 서브넷 |

| ALB | 외부 트래픽 진입점 |

| EKSCluster | Kubernetes 클러스터 |

| Pod | 애플리케이션 실행 단위 |

| ServiceAccount | Pod가 사용하는 Kubernetes 권한 주체 |

| IAMRole | AWS 권한 위임 역할 |

| IAMPolicy | IAM Role에 연결된 권한 정책 |

| S3Bucket | 객체 저장소 |

| RDS | 관계형 데이터베이스 |

| Redis | 캐시 저장소 |

| SecretsManager | 민감정보 저장소 |

| KMSKey | 암호화 키 |

| ECRRepository | 컨테이너 이미지 저장소 |

| CloudWatchLog | 로그 저장소 |

| Finding | 취약점 또는 보안 설정 오류 |



\---



\## 4. 주요 관계 타입



| Relation Type | 설명 |

|---|---|

| CONTAINS | 상위 자산이 하위 자산을 포함 |

| EXPOSED\_TO\_INTERNET | 인터넷에서 접근 가능한 자산 |

| CAN\_MOVE\_TO | 공격자가 이동 가능한 경로 |

| RUNS\_ON | Pod가 EKSCluster에서 실행됨 |

| USES\_SERVICE\_ACCOUNT | Pod가 ServiceAccount를 사용 |

| ASSUMES\_ROLE | ServiceAccount가 IAM Role을 Assume |

| HAS\_POLICY | IAM Role에 IAM Policy가 연결됨 |

| CAN\_READ | 특정 자산에 대한 읽기 권한 존재 |

| CAN\_ACCESS\_SECRET | Secrets Manager Secret 조회 가능 |

| ENCRYPTED\_BY | KMS Key로 암호화됨 |

| PULLS\_IMAGE\_FROM | 컨테이너 이미지를 ECR에서 가져옴 |

| LOGS\_TO | 로그를 CloudWatch로 전송 |

| HAS\_FINDING | 자산에 취약점 또는 설정 오류 존재 |



\---



\## 5. 공격 경로 탐색 대상 관계



공격 경로 탐색 시 모든 관계를 따라가지 않고, 공격 가능성을 의미하는 관계만 필터링한다.



탐색 대상 관계는 다음과 같다.



```cypher

\[

&#x20; "EXPOSED\_TO\_INTERNET",

&#x20; "ALLOWS\_TRAFFIC",

&#x20; "CAN\_MOVE\_TO",

&#x20; "USES\_SERVICE\_ACCOUNT",

&#x20; "ASSUMES\_ROLE",

&#x20; "HAS\_POLICY",

&#x20; "GRANTS\_PERMISSION",

&#x20; "CAN\_READ",

&#x20; "CAN\_WRITE",

&#x20; "CAN\_ACCESS\_SECRET"

]

