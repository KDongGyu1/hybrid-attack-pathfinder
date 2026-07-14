// =====================================================
// Hybrid Attack Path Backend1
// Attack Path Queries
// Final identity / credential structure aligned
// =====================================================

// Q1. S1-A: On-Prem Web Key -> Prefix-restricted S3 access
MATCH path =
  (credential:Credential {id: "hap-onprem-web-key"})
  -[:HAS_PERMISSION]->
  (policy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
  -[access:CAN_ACCESS]->
  (target:S3Bucket)
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  access.action AS action,
  access.resourcePrefix AS resourcePrefix,
  target.id AS targetId,
  path
ORDER BY targetId, resourcePrefix;

// Q2. S1-B: IAM User Key -> User -> Role -> Policy -> Customer S3
MATCH path =
  (credential:Credential {id: "hap-dev-01-access-key"})
  -[:AUTHENTICATES_AS]->
  (user:IAMUser {id: "hap-dev-01-user"})
  -[:ASSUMES_ROLE]->
  (role:IAMRole {id: "hap-s3-readonly-role"})
  -[:HAS_PERMISSION]->
  (policy:IAMPolicy {id: "hap-s3-readonly-policy"})
  -[:CAN_ACCESS]->
  (target:S3Bucket {id: "hap-customer-data-s3"})
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  [rel IN relationships(path) | type(rel)] AS relationTypes,
  path;

// Q3. Scenario 3: WordPress -> Web Key -> Web Policy -> Customer S3
MATCH path =
  (web:OnPremWeb {id: "hap-onprem-web"})
  -[:HAS_CREDENTIAL]->
  (credential:Credential {id: "hap-onprem-web-key"})
  -[:HAS_PERMISSION]->
  (policy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
  -[access:CAN_ACCESS]->
  (target:S3Bucket {id: "hap-customer-data-s3"})
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  access.action AS action,
  access.resourcePrefix AS resourcePrefix,
  path
ORDER BY resourcePrefix;

// Q4. Web Key must not authenticate as hap-dev-01-user
// 결과 없음이 정상
MATCH path =
  (:Credential {id: "hap-onprem-web-key"})
  -[:AUTHENTICATES_AS]->
  (:IAMUser {id: "hap-dev-01-user"})
RETURN path;

// Q5. DB Key must not reach customer S3
// 결과 없음이 정상
MATCH path =
  (:Credential {id: "hap-onprem-db-key"})
  -[*1..6]->
  (:S3Bucket {id: "hap-customer-data-s3"})
RETURN path;

// Q6. DB Key log-only path
MATCH path =
  (db:OnPremDB {id: "hap-onprem-db"})
  -[:HAS_CREDENTIAL]->
  (credential:Credential {id: "hap-onprem-db-key"})
  -[:HAS_PERMISSION]->
  (policy:IAMPolicy {id: "hap-onprem-db-log-policy"})
  -[access:CAN_ACCESS]->
  (target:S3Bucket {id: "hap-soc-log-s3"})
RETURN
  [node IN nodes(path) | node.id] AS nodeIds,
  access.action AS action,
  access.resourcePrefix AS resourcePrefix,
  path;

// Q7. Scenario 2: Internet -> ALB -> Pod -> RDS
MATCH path =
  (:Internet {id: "internet"})
  -[:EXPOSED_TO_INTERNET]->
  (:ALB {id: "hap-public-web-alb"})
  -[:CAN_MOVE_TO]->
  (:Pod {id: "pod-gitea-app"})
  -[:CONNECTS_TO]->
  (:RDS {id: "hap-gitea-db"})
RETURN path;

// Q8. Scenario 4: Pod -> ServiceAccount -> IRSA -> Secret -> RDS
MATCH path =
  (:Pod {id: "pod-gitea-app"})
  -[:USES_SERVICE_ACCOUNT]->
  (:ServiceAccount {id: "gitea-sa"})
  -[:IRSA_LINKED_TO]->
  (:IAMRole {id: "hap-irsa-gitea-role"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-gitea-role-policy"})
  -[:CAN_ACCESS]->
  (:SecretsManager {id: "hap-gitea-db-secret"})
  -[:CONNECTS_TO]->
  (:RDS {id: "hap-gitea-db"})
RETURN path;

// Q9. ALB log destination
MATCH path =
  (:ALB {id: "hap-public-web-alb"})
  -[:LOGS_TO]->
  (:S3Bucket {id: "hap-soc-alb-log-s3"})
RETURN path;

// Q10. Log bucket encryption validation
MATCH (bucket:S3Bucket)
WHERE bucket.id IN ["hap-soc-log-s3", "hap-soc-alb-log-s3"]
OPTIONAL MATCH (bucket)-[:ENCRYPTED_BY]->(kms:KMSKey)
RETURN
  bucket.id AS bucketId,
  bucket.encryption AS encryption,
  bucket.objectLock AS objectLock,
  kms.id AS kmsId
ORDER BY bucketId;

// Q11. Redis / VPN / Management Server absence validation
// 결과 없음이 정상
MATCH (n)
WHERE toLower(coalesce(n.id, "")) CONTAINS "redis"
   OR toLower(coalesce(n.name, "")) CONTAINS "redis"
   OR toLower(coalesce(n.id, "")) CONTAINS "vpn"
   OR toLower(coalesce(n.name, "")) CONTAINS "vpn"
   OR toLower(coalesce(n.id, "")) CONTAINS "management-server"
   OR toLower(coalesce(n.name, "")) CONTAINS "management server"
RETURN n;

// Q12. Final resource ID validation
MATCH (n)
WHERE n.id IN [
  "hap-onprem-web",
  "hap-onprem-web-key",
  "hap-onprem-web-s3-policy",
  "hap-onprem-db",
  "hap-onprem-db-key",
  "hap-onprem-db-log-policy",
  "hap-dev-01-user",
  "hap-dev-01-access-key",
  "hap-s3-readonly-role",
  "hap-s3-readonly-policy",
  "hap-customer-data-s3",
  "hap-soc-log-s3",
  "hap-soc-alb-log-s3",
  "hap-irsa-gitea-role",
  "hap-gitea-role-policy",
  "gitea-sa",
  "hap-gitea-db"
]
RETURN n.id AS id, labels(n) AS labels, n.name AS name
ORDER BY id;

// Q13. Credential ownership validation
MATCH (owner)-[:HAS_CREDENTIAL]->(credential:Credential)
RETURN owner.id AS ownerId, credential.id AS credentialId
ORDER BY ownerId;

// Q14. Relationship type inventory
MATCH ()-[r]->()
RETURN type(r) AS relationType, count(r) AS count
ORDER BY relationType;

// Q15. Full graph
MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 200;
