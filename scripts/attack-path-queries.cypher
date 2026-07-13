// =====================================================
// Hybrid Attack Path Backend1
// Attack Path Queries
// Infra Spec v2 aligned
// =====================================================


// =====================================================
// Q1. S3: On-Prem WordPress → IAM Access Key → S3
// =====================================================

MATCH path =
  (start {id: "hap-onprem-web"})
  -[r*1..8]->
  (target {id: "hap-customer-data-s3"})
WHERE ALL(
  rel IN relationships(path)
  WHERE type(rel) IN [
    "CONNECTS_TO",
    "HAS_ACCESS_KEY",
    "AUTHENTICATES_AS",
    "HAS_PERMISSION",
    "CAN_ACCESS"
  ]
)
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;


// =====================================================
// Q2. S1: IAM Access Key → IAM User → S3
// =====================================================

MATCH path =
  (start {id: "hap-onprem-access-key"})
  -[r*1..8]->
  (target {id: "hap-customer-data-s3"})
WHERE ALL(
  rel IN relationships(path)
  WHERE type(rel) IN [
    "AUTHENTICATES_AS",
    "HAS_PERMISSION",
    "CAN_ACCESS"
  ]
)
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;


// =====================================================
// Q3. S4: Internet → ALB → Pod → IRSA → S3
// =====================================================

MATCH path =
  (start {id: "internet"})
  -[r*1..8]->
  (target {id: "hap-customer-data-s3"})
WHERE ALL(
  rel IN relationships(path)
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
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;


// =====================================================
// Q4. Internet → ALB → Pod → RDS
// =====================================================

MATCH path =
  (start {id: "internet"})
  -[r*1..8]->
  (target {id: "hap-gitea-db"})
WHERE ALL(
  rel IN relationships(path)
  WHERE type(rel) IN [
    "EXPOSED_TO_INTERNET",
    "ALLOWS_TRAFFIC",
    "CAN_MOVE_TO",
    "CONNECTS_TO"
  ]
)
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;


// =====================================================
// Q5. Pod → IRSA → Secrets Manager → RDS
// =====================================================

MATCH path =
  (start {id: "pod-gitea-app"})
  -[r*1..8]->
  (target {id: "hap-gitea-db"})
WHERE ALL(
  rel IN relationships(path)
  WHERE type(rel) IN [
    "USES_SERVICE_ACCOUNT",
    "IRSA_LINKED_TO",
    "HAS_PERMISSION",
    "CAN_ACCESS",
    "CAN_ACCESS_SECRET",
    "CONNECTS_TO"
  ]
)
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;


// =====================================================
// Q6. 전체 그래프
// =====================================================

MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 150;


// =====================================================
// Q7. Redis 제거 확인
// 결과 없음이 정상
// =====================================================

MATCH (n)
WHERE toLower(coalesce(n.id, "")) CONTAINS "redis"
   OR toLower(coalesce(n.name, "")) CONTAINS "redis"
   OR toLower(coalesce(n.displayName, "")) CONTAINS "redis"
RETURN n;


// =====================================================
// Q8. 확정 리소스 ID 확인
// =====================================================

MATCH (n)
WHERE n.id IN [
  "hap-dev-01-user",
  "hap-s3-access-policy",
  "hap-s3-readonly-role",
  "hap-irsa-gitea-role",
  "hap-gitea-role-policy",
  "gitea-sa",
  "hap-gitea-db",
  "hap-customer-data-s3",
  "hap-soc-log-s3",
  "hap-soc-alb-log-s3",
  "hap-prod-vpc",
  "hap-soc-vpc",
  "hap-onprem-web",
  "hap-onprem-db",
  "hap-onprem-access-key"
]
RETURN
  n.id AS id,
  labels(n) AS labels,
  n.name AS name
ORDER BY id;


// =====================================================
// Q9. 관계 타입 확인
// =====================================================

MATCH ()-[r]->()
RETURN
  type(r) AS relationType,
  count(r) AS count
ORDER BY relationType;


// =====================================================
// Q10. 노드 타입 확인
// =====================================================

MATCH (n)
RETURN
  labels(n) AS nodeLabels,
  count(n) AS count
ORDER BY toString(nodeLabels);


// =====================================================
// Q11. S3 버킷 분리 확인
// =====================================================

MATCH (bucket:S3Bucket)
WHERE bucket.id IN [
  "hap-customer-data-s3",
  "hap-soc-log-s3",
  "hap-soc-alb-log-s3"
]
RETURN
  bucket.id AS bucketId,
  bucket.purpose AS purpose,
  bucket.encryption AS encryption,
  bucket.objectLock AS objectLock,
  bucket.prodPrefix AS prodPrefix,
  bucket.socPrefix AS socPrefix
ORDER BY bucketId;


// =====================================================
// Q12. Prod ALB 로그 저장 경로 확인
// =====================================================

MATCH path =
  (alb:ALB {id: "hap-public-web-alb"})
  -[:LOGS_TO]->
  (bucket:S3Bucket {id: "hap-soc-alb-log-s3"})
RETURN path;


// =====================================================
// Q13. KMS 연결 확인
// hap-soc-log-s3만 나와야 정상
// =====================================================

MATCH
  (bucket:S3Bucket)-[:ENCRYPTED_BY]->(kms:KMSKey)
WHERE bucket.id IN [
  "hap-soc-log-s3",
  "hap-soc-alb-log-s3"
]
RETURN
  bucket.id AS bucketId,
  bucket.encryption AS encryption,
  kms.id AS kmsId;


// =====================================================
// Q14. ALB 로그 버킷이 KMS에 연결되지 않았는지 확인
// 결과 없음이 정상
// =====================================================

MATCH
  (bucket:S3Bucket {id: "hap-soc-alb-log-s3"})
  -[:ENCRYPTED_BY]->
  (kms:KMSKey)
RETURN bucket, kms;