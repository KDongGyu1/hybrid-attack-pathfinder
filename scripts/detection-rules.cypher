// Hybrid Attack Path Backend1
// Detection rules for Event nodes linked to the attack-path graph.
//
// Expected Event properties:
// event_id, event_time, source_type, log_type, actor_id, actor_type, source_ip,
// action, source_asset_id, target_asset_id, result, severity_hint, raw_log_ref,
// access_key_id, credential_id, request_id, session_id, role_arn, service_account,
// pod_id, secret_arn, kms_key_id, bucket_name, object_key, resource_prefix,
// database_user, attributes
//
// Minimal event graph relationships:
// (:Event)-[:PERFORMED_BY]->(:IAMUser|:ServiceAccount|:Identity)
// (:Event)-[:ORIGINATED_FROM]->(:Asset)
// (:Event)-[:TARGETED]->(:Asset)
// (:Event)-[:USES_CREDENTIAL]->(:Credential)
// (:Event)-[:MATCHES_SCENARIO]->(:Scenario)

// R0. Link events to known graph nodes by stable IDs.
MATCH (e:Event)
OPTIONAL MATCH (actor {id: e.actor_id})
FOREACH (_ IN CASE WHEN actor IS NULL THEN [] ELSE [1] END |
  MERGE (e)-[:PERFORMED_BY]->(actor)
)
WITH e
OPTIONAL MATCH (source {id: e.source_asset_id})
FOREACH (_ IN CASE WHEN source IS NULL THEN [] ELSE [1] END |
  MERGE (e)-[:ORIGINATED_FROM]->(source)
)
WITH e
OPTIONAL MATCH (target {id: e.target_asset_id})
FOREACH (_ IN CASE WHEN target IS NULL THEN [] ELSE [1] END |
  MERGE (e)-[:TARGETED]->(target)
)
WITH e
OPTIONAL MATCH (credential:Credential {id: coalesce(e.credential_id, e.access_key_id)})
FOREACH (_ IN CASE WHEN credential IS NULL THEN [] ELSE [1] END |
  MERGE (e)-[:USES_CREDENTIAL]->(credential)
)
RETURN count(e) AS linked_event_count;

// R1. S2 detection: abnormal HTTP request -> Gitea Pod behavior -> RDS activity.
MATCH (albEvent:Event)
WHERE albEvent.source_asset_id = "hap-prod-alb"
  AND albEvent.target_asset_id = "pod-gitea-app"
  AND albEvent.action IN ["HTTP_REQUEST", "ALB_REQUEST", "FORWARD"]
  AND coalesce(albEvent.result, "UNKNOWN") <> "BLOCKED"
MATCH (podEvent:Event)
WHERE podEvent.pod_id = "pod-gitea-app"
  AND podEvent.event_time >= albEvent.event_time
  AND (
    podEvent.request_id = albEvent.request_id
    OR podEvent.source_ip = albEvent.source_ip
    OR podEvent.source_asset_id = "pod-gitea-app"
  )
MATCH (rdsEvent:Event)
WHERE rdsEvent.target_asset_id = "hap-gitea-db"
  AND rdsEvent.event_time >= podEvent.event_time
  AND (
    rdsEvent.request_id = podEvent.request_id
    OR rdsEvent.pod_id = "pod-gitea-app"
    OR rdsEvent.source_asset_id = "pod-gitea-app"
  )
RETURN
  "S2" AS scenario_id,
  "Internet to Gitea Pod and RDS event chain" AS scenario_name,
  "HIGH" AS severity,
  min(albEvent.event_time) AS first_event_time,
  max(rdsEvent.event_time) AS last_event_time,
  count(DISTINCT albEvent) + count(DISTINCT podEvent) + count(DISTINCT rdsEvent) AS evidence_count,
  collect(DISTINCT albEvent.event_id) + collect(DISTINCT podEvent.event_id) + collect(DISTINCT rdsEvent.event_id) AS event_ids,
  albEvent.source_asset_id AS source_asset_id,
  rdsEvent.target_asset_id AS target_asset_id,
  coalesce(podEvent.credential_id, rdsEvent.credential_id) AS credential_id,
  coalesce(podEvent.actor_id, rdsEvent.actor_id) AS actor_id,
  ["hap-prod-alb", "pod-gitea-app", "hap-gitea-db"] AS graph_node_ids;

// R2. S3 detection: On-Prem web key writes to WordPress backup prefixes.
MATCH (e:Event)
WHERE coalesce(e.credential_id, e.access_key_id) = "hap-onprem-web-key"
  AND e.bucket_name = "hap-customer-data-s3"
  AND e.action = "s3:PutObject"
  AND (
    e.resource_prefix IN ["wordpress-files/", "wordpress-db/"]
    OR e.object_key STARTS WITH "wordpress-files/"
    OR e.object_key STARTS WITH "wordpress-db/"
  )
RETURN
  "S3-WEB-CUSTOMER-S3" AS scenario_id,
  "On-Prem web key PutObject to customer S3 backup prefix" AS scenario_name,
  coalesce(e.severity_hint, "MEDIUM") AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  "hap-onprem-web-key" AS credential_id,
  e.actor_id AS actor_id,
  ["hap-onprem-web", "hap-onprem-web-key", "hap-onprem-web-s3-policy", "hap-customer-data-s3"] AS graph_node_ids;

// R3. S3 detection: On-Prem web key writes logs to hap-soc-log-s3/onprem/.
MATCH (e:Event)
WHERE coalesce(e.credential_id, e.access_key_id) = "hap-onprem-web-key"
  AND e.bucket_name = "hap-soc-log-s3"
  AND e.action = "s3:PutObject"
  AND (e.resource_prefix = "onprem/" OR e.object_key STARTS WITH "onprem/")
RETURN
  "S3-WEB-LOG-S3" AS scenario_id,
  "On-Prem web key PutObject to SOC log prefix" AS scenario_name,
  coalesce(e.severity_hint, "LOW") AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  "hap-soc-log-s3" AS target_asset_id,
  "hap-onprem-web-key" AS credential_id,
  e.actor_id AS actor_id,
  ["hap-onprem-web", "hap-onprem-web-key", "hap-onprem-web-s3-policy", "hap-soc-log-s3"] AS graph_node_ids;

// R4. S4 detection: AssumeRoleWithWebIdentity -> GetSecretValue -> optional KMS decrypt -> RDS.
MATCH (assume:Event)
WHERE assume.action = "sts:AssumeRoleWithWebIdentity"
  AND assume.service_account = "gitea-sa"
  AND coalesce(assume.role_arn, "") CONTAINS "hap-irsa-gitea-role"
MATCH (secretRead:Event)
WHERE secretRead.action = "secretsmanager:GetSecretValue"
  AND secretRead.event_time >= assume.event_time
  AND (
    secretRead.session_id = assume.session_id
    OR secretRead.pod_id = assume.pod_id
    OR secretRead.service_account = "gitea-sa"
  )
  AND (
    secretRead.target_asset_id = "gitea-db-credentials"
    OR coalesce(secretRead.secret_arn, "") CONTAINS "hap-db-secret"
    OR coalesce(secretRead.secret_arn, "") CONTAINS "gitea-db-credentials"
  )
OPTIONAL MATCH (kms:Event)
WHERE kms.action = "kms:Decrypt"
  AND kms.event_time >= secretRead.event_time
  AND (
    kms.session_id = assume.session_id
    OR kms.pod_id = assume.pod_id
    OR kms.kms_key_id = "hap-prod-secrets-cmk"
  )
OPTIONAL MATCH (rds:Event)
WHERE rds.target_asset_id = "hap-gitea-db"
  AND rds.event_time >= secretRead.event_time
  AND (
    rds.session_id = assume.session_id
    OR rds.pod_id = assume.pod_id
    OR rds.database_user IS NOT NULL
  )
RETURN
  "S4" AS scenario_id,
  "Gitea Pod IRSA secret access toward RDS" AS scenario_name,
  "HIGH" AS severity,
  min(assume.event_time) AS first_event_time,
  max(coalesce(rds.event_time, kms.event_time, secretRead.event_time)) AS last_event_time,
  count(DISTINCT assume) + count(DISTINCT secretRead) + count(DISTINCT kms) + count(DISTINCT rds) AS evidence_count,
  collect(DISTINCT assume.event_id) + collect(DISTINCT secretRead.event_id) + collect(DISTINCT kms.event_id) + collect(DISTINCT rds.event_id) AS event_ids,
  assume.pod_id AS source_asset_id,
  coalesce(rds.target_asset_id, "gitea-db-credentials") AS target_asset_id,
  null AS credential_id,
  assume.service_account AS actor_id,
  ["pod-gitea-app", "gitea-sa", "hap-irsa-gitea-role", "hap-gitea-role-policy", "gitea-db-credentials", "hap-gitea-db"] AS graph_node_ids;

// R5. S1-A detection: dev-01 key authenticates as IAM user and accesses customer S3 directly.
MATCH (auth:Event)
WHERE coalesce(auth.credential_id, auth.access_key_id) = "hap-dev-01-access-key"
  AND auth.actor_id = "hap-dev-01-user"
MATCH (s3:Event)
WHERE coalesce(s3.credential_id, s3.access_key_id) = "hap-dev-01-access-key"
  AND s3.bucket_name = "hap-customer-data-s3"
  AND s3.action IN ["s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:*"]
  AND s3.event_time >= auth.event_time
RETURN
  "S1-A" AS scenario_id,
  "dev-01 key direct policy customer S3 access" AS scenario_name,
  "HIGH" AS severity,
  min(auth.event_time) AS first_event_time,
  max(s3.event_time) AS last_event_time,
  count(DISTINCT auth) + count(DISTINCT s3) AS evidence_count,
  collect(DISTINCT auth.event_id) + collect(DISTINCT s3.event_id) AS event_ids,
  auth.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  "hap-dev-01-access-key" AS credential_id,
  "hap-dev-01-user" AS actor_id,
  ["hap-dev-01-access-key", "hap-dev-01-user", "hap-s3-access-policy", "hap-customer-data-s3"] AS graph_node_ids;

// R6. S1-B detection: dev-01 key assumes readonly role and reads customer S3.
MATCH (assume:Event)
WHERE coalesce(assume.credential_id, assume.access_key_id) = "hap-dev-01-access-key"
  AND assume.actor_id = "hap-dev-01-user"
  AND assume.action = "sts:AssumeRole"
  AND coalesce(assume.role_arn, "") CONTAINS "hap-s3-readonly-role"
MATCH (s3:Event)
WHERE s3.action IN ["s3:GetObject", "s3:ListBucket"]
  AND s3.bucket_name = "hap-customer-data-s3"
  AND s3.event_time >= assume.event_time
  AND (s3.session_id = assume.session_id OR coalesce(s3.role_arn, "") CONTAINS "hap-s3-readonly-role")
RETURN
  "S1-B" AS scenario_id,
  "dev-01 key assumes readonly role to customer S3" AS scenario_name,
  "HIGH" AS severity,
  min(assume.event_time) AS first_event_time,
  max(s3.event_time) AS last_event_time,
  count(DISTINCT assume) + count(DISTINCT s3) AS evidence_count,
  collect(DISTINCT assume.event_id) + collect(DISTINCT s3.event_id) AS event_ids,
  assume.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  "hap-dev-01-access-key" AS credential_id,
  "hap-dev-01-user" AS actor_id,
  ["hap-dev-01-access-key", "hap-dev-01-user", "hap-s3-readonly-role", "hap-s3-readonly-policy", "hap-customer-data-s3"] AS graph_node_ids;
