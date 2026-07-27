// Hybrid Attack Path Backend1
// Detection rules for Event nodes linked to the attack-path graph.
//
// Rule status semantics:
// REPRODUCED means the attack has been replayed and supported by logs.
// DETECTABLE means a detection rule exists but no matching Event may exist.
// DETECTED means current Event nodes match the rule.
// POTENTIAL means only the asset/permission/network graph path exists.
//
// Expected Event properties:
// event_id, event_time, source_type, log_type, actor_id, actor_type, source_ip,
// action, source_asset_id, target_asset_id, result, severity_hint, raw_log_ref,
// access_key_id, credential_id, request_id, session_id, role_arn, service_account,
// pod_id, secret_arn, kms_key_id, bucket_name, object_key, resource_prefix,
// database_user, user_agent, is_unusual_ip, is_unusual_region,
// is_unusual_user_agent, is_abnormal, connection_path, attributes

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

// D1. Unusual IP or region IAM Access Key usage.
MATCH (e:Event)
WHERE coalesce(e.credential_id, e.access_key_id) IS NOT NULL
  AND (coalesce(e.is_unusual_ip, false) = true OR coalesce(e.is_unusual_region, false) = true)
RETURN
  "D1" AS scenario_id,
  "IAM access key used from unusual IP or region" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  coalesce(e.severity_hint, "HIGH") AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  e.actor_id AS actor_id,
  collect(DISTINCT coalesce(e.source_asset_id, e.actor_id)) AS graph_node_ids;

// D2. Repeated AssumeRole in a short period.
MATCH (e:Event)
WHERE e.action = "sts:AssumeRole"
WITH e.actor_id AS actor_id, e.role_arn AS role_arn, collect(e) AS events
WHERE size(events) >= 5
UNWIND events AS e
RETURN
  "D2" AS scenario_id,
  "Repeated AssumeRole in short time window" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "MEDIUM" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  e.actor_id AS actor_id,
  collect(DISTINCT e.actor_id) AS graph_node_ids;

// D3. AssumeRole followed by customer S3 ListBucket/GetObject.
MATCH (assume:Event)
WHERE assume.action IN ["sts:AssumeRole", "sts:AssumeRoleWithWebIdentity"]
MATCH (s3:Event)
WHERE s3.bucket_name = "hap-customer-data-s3"
  AND s3.action IN ["s3:ListBucket", "s3:GetObject"]
  AND s3.event_time >= assume.event_time
  AND (s3.session_id = assume.session_id OR s3.actor_id = assume.actor_id)
RETURN
  "D3" AS scenario_id,
  "AssumeRole followed by customer S3 read" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(assume.event_time) AS first_event_time,
  max(s3.event_time) AS last_event_time,
  count(DISTINCT assume) + count(DISTINCT s3) AS evidence_count,
  collect(DISTINCT assume.event_id) + collect(DISTINCT s3.event_id) AS event_ids,
  assume.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  coalesce(assume.credential_id, assume.access_key_id) AS credential_id,
  assume.actor_id AS actor_id,
  collect(DISTINCT assume.actor_id) + ["hap-customer-data-s3"] AS graph_node_ids;

// D4. S3 PutObject outside allowed prefixes.
MATCH (e:Event)
WHERE e.bucket_name = "hap-customer-data-s3"
  AND e.action = "s3:PutObject"
  AND NOT (
    e.resource_prefix IN ["wordpress-files/", "wordpress-db/"]
    OR e.object_key STARTS WITH "wordpress-files/"
    OR e.object_key STARTS WITH "wordpress-db/"
  )
RETURN
  "D4" AS scenario_id,
  "S3 PutObject outside allowed prefixes" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  e.actor_id AS actor_id,
  collect(DISTINCT coalesce(e.source_asset_id, e.actor_id)) + ["hap-customer-data-s3"] AS graph_node_ids;

// D5. WordPress compromise followed by hap-onprem-web-key use.
MATCH (e:Event)
WHERE e.source_asset_id = "hap-onprem-web"
  AND coalesce(e.credential_id, e.access_key_id) = "hap-onprem-web-key"
RETURN
  "D5" AS scenario_id,
  "WordPress compromise followed by hap-onprem-web-key use" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  coalesce(e.severity_hint, "HIGH") AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  "hap-onprem-web" AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  "hap-onprem-web-key" AS credential_id,
  e.actor_id AS actor_id,
  ["hap-onprem-web", "hap-onprem-web-key"] AS graph_node_ids;

// D6. Unexpected GetSecretValue from a Pod.
MATCH (e:Event)
WHERE e.pod_id = "pod-gitea-app"
  AND e.action = "secretsmanager:GetSecretValue"
  AND NOT (
    e.target_asset_id = "gitea-db-credentials"
    OR coalesce(e.secret_arn, "") CONTAINS "hap-db-secret"
  )
RETURN
  "D6" AS scenario_id,
  "Unexpected GetSecretValue from Pod" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  "pod-gitea-app" AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  coalesce(e.actor_id, e.service_account) AS actor_id,
  ["pod-gitea-app", coalesce(e.target_asset_id, e.secret_arn)] AS graph_node_ids;

// D7. GetSecretValue followed by KMS Decrypt and RDS access.
MATCH (secretRead:Event)
WHERE secretRead.action = "secretsmanager:GetSecretValue"
MATCH (kms:Event)
WHERE kms.action = "kms:Decrypt"
  AND kms.event_time >= secretRead.event_time
  AND (kms.session_id = secretRead.session_id OR kms.pod_id = secretRead.pod_id)
MATCH (rds:Event)
WHERE rds.target_asset_id = "hap-gitea-db"
  AND rds.event_time >= kms.event_time
  AND (rds.session_id = secretRead.session_id OR rds.pod_id = secretRead.pod_id)
RETURN
  "D7" AS scenario_id,
  "GetSecretValue followed by KMS Decrypt and RDS access" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(secretRead.event_time) AS first_event_time,
  max(rds.event_time) AS last_event_time,
  count(DISTINCT secretRead) + count(DISTINCT kms) + count(DISTINCT rds) AS evidence_count,
  collect(DISTINCT secretRead.event_id) + collect(DISTINCT kms.event_id) + collect(DISTINCT rds.event_id) AS event_ids,
  secretRead.pod_id AS source_asset_id,
  "hap-gitea-db" AS target_asset_id,
  coalesce(secretRead.credential_id, secretRead.access_key_id) AS credential_id,
  coalesce(secretRead.actor_id, secretRead.service_account) AS actor_id,
  ["pod-gitea-app", "gitea-db-credentials", "hap-prod-secrets-cmk", "hap-gitea-db"] AS graph_node_ids;

// D8. Abnormal Pod behavior immediately after internal ALB attack.
MATCH (alb:Event)
WHERE alb.source_asset_id = "hap-prod-alb"
  AND alb.target_asset_id = "pod-gitea-app"
MATCH (e:Event)
WHERE e.pod_id = "pod-gitea-app"
  AND e.event_time >= alb.event_time
  AND coalesce(e.is_abnormal, false) = true
RETURN
  "D8" AS scenario_id,
  "Abnormal Pod behavior after internal ALB attack" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(alb.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(DISTINCT alb) + count(DISTINCT e) AS evidence_count,
  collect(DISTINCT alb.event_id) + collect(DISTINCT e.event_id) AS event_ids,
  "hap-prod-alb" AS source_asset_id,
  "pod-gitea-app" AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  coalesce(e.actor_id, e.service_account) AS actor_id,
  ["hap-prod-alb", "pod-gitea-app"] AS graph_node_ids;

// D9. Unexpected direct RDS access from Pod.
MATCH (e:Event)
WHERE e.pod_id = "pod-gitea-app"
  AND e.target_asset_id = "hap-gitea-db"
  AND coalesce(e.connection_path, "") <> "application"
RETURN
  "D9" AS scenario_id,
  "Unexpected direct RDS access from Pod" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  "pod-gitea-app" AS source_asset_id,
  "hap-gitea-db" AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  coalesce(e.actor_id, e.service_account) AS actor_id,
  ["pod-gitea-app", "hap-gitea-db"] AS graph_node_ids;

// D10. DB log-only credential attempts customer S3 access.
MATCH (e:Event)
WHERE coalesce(e.credential_id, e.access_key_id) = "hap-onprem-db-key"
  AND e.bucket_name = "hap-customer-data-s3"
RETURN
  "D10" AS scenario_id,
  "DB log-only credential attempts customer S3 access" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "HIGH" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  "hap-customer-data-s3" AS target_asset_id,
  "hap-onprem-db-key" AS credential_id,
  e.actor_id AS actor_id,
  ["hap-onprem-db", "hap-onprem-db-key", "hap-customer-data-s3"] AS graph_node_ids;

// D11. Repeated AccessDenied.
MATCH (e:Event)
WHERE e.result = "AccessDenied"
WITH coalesce(e.actor_id, e.credential_id, e.source_ip) AS principal, collect(e) AS events
WHERE size(events) >= 5
UNWIND events AS e
RETURN
  "D11" AS scenario_id,
  "Repeated AccessDenied" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "MEDIUM" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  e.actor_id AS actor_id,
  collect(DISTINCT coalesce(e.actor_id, e.credential_id, e.source_ip)) AS graph_node_ids;

// D12. Unusual User-Agent AWS API calls.
MATCH (e:Event)
WHERE coalesce(e.user_agent, "") <> ""
  AND (
    coalesce(e.is_unusual_user_agent, false) = true
    OR NOT e.user_agent STARTS WITH "aws-cli/"
  )
RETURN
  "D12" AS scenario_id,
  "AWS API calls from unusual User-Agent" AS scenario_name,
  "DETECTABLE" AS scenario_status,
  "MEDIUM" AS severity,
  min(e.event_time) AS first_event_time,
  max(e.event_time) AS last_event_time,
  count(e) AS evidence_count,
  collect(e.event_id) AS event_ids,
  e.source_asset_id AS source_asset_id,
  e.target_asset_id AS target_asset_id,
  coalesce(e.credential_id, e.access_key_id) AS credential_id,
  e.actor_id AS actor_id,
  collect(DISTINCT coalesce(e.actor_id, e.user_agent)) AS graph_node_ids;
