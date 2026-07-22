// Hybrid Attack Path Backend1
// Attack path and validation queries aligned with scripts/seed.cypher.

// Q1. S1-A: dev-01 access key -> IAM user -> direct policy -> customer S3.
MATCH path =
  (:Credential {id: "hap-dev-01-access-key"})
  -[:AUTHENTICATES_AS]->
  (:IAMUser {id: "hap-dev-01-user"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-s3-access-policy"})
  -[:CAN_ACCESS]->
  (:S3Bucket {id: "hap-customer-data-s3"})
RETURN
  "S1-A" AS scenario_id,
  "dev-01 direct policy to customer S3" AS scenario_name,
  "HIGH" AS severity,
  [node IN nodes(path) | node.id] AS node_ids,
  [rel IN relationships(path) | type(rel)] AS relation_types,
  path;

// Q2. S1-B: dev-01 access key -> IAM user -> assumed role -> readonly policy -> customer S3.
MATCH path =
  (:Credential {id: "hap-dev-01-access-key"})
  -[:AUTHENTICATES_AS]->
  (:IAMUser {id: "hap-dev-01-user"})
  -[:ASSUMES_ROLE]->
  (:IAMRole {id: "hap-s3-readonly-role"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-s3-readonly-policy"})
  -[:CAN_ACCESS]->
  (:S3Bucket {id: "hap-customer-data-s3"})
RETURN
  "S1-B" AS scenario_id,
  "dev-01 assume role to customer S3" AS scenario_name,
  "HIGH" AS severity,
  [node IN nodes(path) | node.id] AS node_ids,
  [rel IN relationships(path) | type(rel)] AS relation_types,
  path;

// Q3. S2: Internet -> Prod ALB -> Gitea Pod -> RDS.
MATCH path =
  (:Internet {id: "internet"})
  -[:EXPOSED_TO_INTERNET]->
  (:ALB {id: "hap-prod-alb"})
  -[:CAN_MOVE_TO]->
  (:Pod {id: "pod-gitea-app"})
  -[:CONNECTS_TO]->
  (:RDS {id: "hap-gitea-db"})
RETURN
  "S2" AS scenario_id,
  "Internet to Gitea Pod and RDS" AS scenario_name,
  "HIGH" AS severity,
  [node IN nodes(path) | node.id] AS node_ids,
  [rel IN relationships(path) | type(rel)] AS relation_types,
  path;

// Q4. S3 Web -> customer S3 prefixes.
MATCH path =
  (:OnPremWeb {id: "hap-onprem-web"})
  -[:HAS_CREDENTIAL]->
  (:Credential {id: "hap-onprem-web-key"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-onprem-web-s3-policy"})
  -[access:CAN_ACCESS]->
  (:S3Bucket {id: "hap-customer-data-s3"})
WHERE access.resourcePrefix IN ["wordpress-files/", "wordpress-db/"]
RETURN
  "S3-WEB-CUSTOMER-S3" AS scenario_id,
  "On-Prem web key to customer S3 prefix" AS scenario_name,
  "MEDIUM" AS severity,
  access.action AS action,
  access.resourcePrefix AS resource_prefix,
  [node IN nodes(path) | node.id] AS node_ids,
  path
ORDER BY resource_prefix;

// Q5. S3 Web -> SOC log prefix.
MATCH path =
  (:OnPremWeb {id: "hap-onprem-web"})
  -[:HAS_CREDENTIAL]->
  (:Credential {id: "hap-onprem-web-key"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-onprem-web-s3-policy"})
  -[access:CAN_ACCESS]->
  (:S3Bucket {id: "hap-soc-log-s3"})
WHERE access.resourcePrefix = "onprem/"
RETURN
  "S3-WEB-LOG-S3" AS scenario_id,
  "On-Prem web key to SOC log prefix" AS scenario_name,
  "LOW" AS severity,
  access.action AS action,
  access.resourcePrefix AS resource_prefix,
  [node IN nodes(path) | node.id] AS node_ids,
  path;

// Q6. On-Prem DB -> SOC log S3 only.
MATCH path =
  (:OnPremDB {id: "hap-onprem-db"})
  -[:HAS_CREDENTIAL]->
  (:Credential {id: "hap-onprem-db-key"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-onprem-db-s3-policy"})
  -[access:CAN_ACCESS]->
  (:S3Bucket {id: "hap-soc-log-s3"})
WHERE access.resourcePrefix = "onprem/"
RETURN
  "ONPREM-DB-LOG-S3" AS scenario_id,
  "On-Prem DB log-only key to SOC logs" AS scenario_name,
  "LOW" AS severity,
  access.action AS action,
  access.resourcePrefix AS resource_prefix,
  [node IN nodes(path) | node.id] AS node_ids,
  path;

// Q7. S4: Pod -> IRSA -> Secret -> RDS.
MATCH path =
  (:Pod {id: "pod-gitea-app"})
  -[:USES_SERVICE_ACCOUNT]->
  (:ServiceAccount {id: "gitea-sa"})
  -[:IRSA_LINKED_TO]->
  (:IAMRole {id: "hap-irsa-gitea-role"})
  -[:HAS_PERMISSION]->
  (:IAMPolicy {id: "hap-gitea-role-policy"})
  -[:CAN_ACCESS]->
  (:SecretsManager {id: "gitea-db-credentials"})
  -[:CONNECTS_TO]->
  (:RDS {id: "hap-gitea-db"})
RETURN
  "S4" AS scenario_id,
  "Gitea Pod IRSA to DB secret and RDS" AS scenario_name,
  "HIGH" AS severity,
  [node IN nodes(path) | node.id] AS node_ids,
  [rel IN relationships(path) | type(rel)] AS relation_types,
  path;

// Q8. Prod ALB log destination.
MATCH path =
  (:ALB {id: "hap-prod-alb"})
  -[logs:LOGS_TO]->
  (:S3Bucket {id: "hap-soc-alb-log-s3"})
RETURN
  "ALB-LOGS" AS scenario_id,
  logs.protocol AS protocol,
  logs.port AS port,
  logs.prefix AS prefix,
  logs.encryption AS encryption,
  [node IN nodes(path) | node.id] AS node_ids,
  path;

// Q9. Resource ID inventory.
MATCH (n)
WHERE n.id IN [
  "hap-prod-alb",
  "hap-eks",
  "pod-gitea-app",
  "gitea-sa",
  "hap-irsa-gitea-role",
  "hap-gitea-role-policy",
  "hap-ecr",
  "gitea-db-credentials",
  "hap-gitea-db",
  "hap-dev-01-access-key",
  "hap-dev-01-user",
  "hap-s3-access-policy",
  "hap-s3-readonly-role",
  "hap-s3-readonly-policy",
  "hap-onprem-web",
  "hap-onprem-web-user",
  "hap-onprem-web-key",
  "hap-onprem-web-s3-policy",
  "hap-onprem-db",
  "hap-onprem-db-user",
  "hap-onprem-db-key",
  "hap-onprem-db-s3-policy",
  "hap-customer-data-s3",
  "hap-soc-log-s3",
  "hap-soc-alb-log-s3",
  "hap-soc-alb-log-s3/config",
  "hap-data-cmk",
  "hap-log-cmk",
  "hap-prod-secrets-cmk",
  "hap-prod-rds-cmk"
]
RETURN
  n.id AS id,
  labels(n) AS labels,
  n.name AS name,
  n.namespace AS namespace,
  coalesce(n.irsaSubject, n.trustedSubject) AS irsa_subject
ORDER BY id;

// Q10. Relationship inventory.
MATCH ()-[r]->()
RETURN type(r) AS relation_type, count(r) AS count
ORDER BY relation_type;

// Q11. Full graph preview.
MATCH (n)-[r]->(m)
RETURN n, r, m
LIMIT 200;

// Q12. Negative validation: Web key must not authenticate as dev-01.
MATCH path =
  (:Credential {id: "hap-onprem-web-key"})
  -[:AUTHENTICATES_AS]->
  (:IAMUser {id: "hap-dev-01-user"})
RETURN path;

// Q13. Negative validation: DB key must not reach customer S3.
MATCH path =
  (:Credential {id: "hap-onprem-db-key"})
  -[*1..6]->
  (:S3Bucket {id: "hap-customer-data-s3"})
RETURN path;

// Q14. Negative validation: removed infrastructure nodes must not exist.
MATCH (n)
WHERE toLower(coalesce(n.id, "")) CONTAINS ("red" + "is")
   OR toLower(coalesce(n.name, "")) CONTAINS ("red" + "is")
   OR toLower(coalesce(n.id, "")) CONTAINS "vpn"
   OR toLower(coalesce(n.name, "")) CONTAINS "vpn"
   OR toLower(coalesce(n.id, "")) CONTAINS "management"
   OR toLower(coalesce(n.name, "")) CONTAINS "management"
   OR n.id = ("hap-public" + "-web-alb")
RETURN n;

// Q15. Final ALB, EKS, Secret, Config, namespace, IRSA subject, and ECR validation.
MATCH (alb:ALB {id: "hap-prod-alb"})
MATCH (eks:EKSCluster {id: "hap-eks"})
MATCH (pod:Pod {id: "pod-gitea-app"})
MATCH (sa:ServiceAccount {id: "gitea-sa"})
MATCH (sa)-[irsa:IRSA_LINKED_TO]->(role:IAMRole {id: "hap-irsa-gitea-role"})
MATCH (secret:SecretsManager {id: "gitea-db-credentials"})
MATCH (albBucket:S3Bucket {id: "hap-soc-alb-log-s3"})
MATCH (albBucket)-[:HAS_LOG_PREFIX]->(config:LogPrefix {id: "hap-soc-alb-log-s3/config"})
MATCH (pod)-[:PULLS_IMAGE_FROM]->(ecr:ECRRepository {id: "hap-ecr"})
WHERE irsa.subject = "system:serviceaccount:prod:gitea-sa"
  AND role.trustedSubject = "system:serviceaccount:prod:gitea-sa"
RETURN
  alb.id AS alb_id,
  alb.protocol AS alb_protocol,
  alb.port AS alb_port,
  eks.version AS eks_version,
  pod.namespace AS pod_namespace,
  sa.namespace AS service_account_namespace,
  irsa.subject AS irsa_subject,
  role.trustedSubject AS role_trusted_subject,
  ecr.id AS ecr_id,
  secret.id AS secret_id,
  secret.awsSecretName AS aws_secret_name,
  albBucket.id + "/" + config.prefix AS config_location;

// Q16. Finding inventory used by risk scoring.
MATCH (n)-[:HAS_FINDING]->(finding:Finding)
RETURN
  n.id AS graph_node_id,
  finding.id AS finding_id,
  finding.source AS source,
  finding.severity AS severity,
  finding.cvss_score AS cvss_score,
  finding.cve_id AS cve_id,
  finding.finding_type AS finding_type,
  finding.status AS status
ORDER BY graph_node_id, finding_id;

// Q17. Scenario status inventory.
MATCH (status:ScenarioStatus)
RETURN status.id AS status_id, status.description AS description
ORDER BY status_id;

// Q18. Deployment value regression checks.
MATCH (pod:Pod {id: "pod-gitea-app"})
MATCH (sa:ServiceAccount {id: "gitea-sa"})
OPTIONAL MATCH (oldNamespace)
WHERE (oldNamespace:Pod OR oldNamespace:ServiceAccount)
  AND oldNamespace.namespace = "gitea"
OPTIONAL MATCH (oldEcr:ECRRepository {id: "hap-gitea-ecr"})
OPTIONAL MATCH (pod)-[pulls:PULLS_IMAGE_FROM]->(:ECRRepository {id: "hap-ecr"})
RETURN
  count(DISTINCT oldNamespace) AS old_namespace_node_count,
  count(DISTINCT oldEcr) AS old_ecr_node_count,
  count(DISTINCT pulls) AS pod_to_hap_ecr_pull_count,
  pod.namespace AS pod_namespace,
  sa.namespace AS service_account_namespace,
  sa.irsaSubject AS service_account_irsa_subject;
