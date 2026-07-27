# Backend1 Neo4j Design

Backend1 represents hybrid infrastructure, IAM permissions, credentials, and
runtime event evidence in Neo4j. The MVP keeps the graph small but executable:
every documented attack path is backed by `scripts/seed.cypher` and queryable
with `scripts/attack-path-queries.cypher`.

## Infrastructure Baseline

The graph follows the latest infra1 baseline inspected from
`origin/feature/infra1-terraform-base`.

| Resource | Graph ID |
| --- | --- |
| Prod ALB | `hap-prod-alb` |
| EKS cluster | `hap-eks` |
| Gitea Pod | `pod-gitea-app` |
| Gitea Pod namespace | `prod` |
| ServiceAccount | `gitea-sa` |
| ServiceAccount namespace | `prod` |
| IRSA subject | `system:serviceaccount:prod:gitea-sa` |
| IRSA role | `hap-irsa-gitea-role` |
| IRSA policy | `hap-gitea-role-policy` |
| ECR repository | `hap-ecr` |
| Mounted DB Secret | `gitea-db-credentials` |
| AWS secret backing value | `hap-db-secret` stored as `awsSecretName` |
| RDS | `hap-gitea-db` |
| Customer S3 | `hap-customer-data-s3` |
| Audit/log S3 | `hap-soc-log-s3` |
| ALB/Config log S3 | `hap-soc-alb-log-s3` |
| Customer-data KMS | `hap-data-cmk` |
| SOC log KMS | `hap-log-cmk` |
| Prod secret KMS | `hap-prod-secrets-cmk` |
| Prod RDS KMS | `hap-prod-rds-cmk` |

Deprecated cache, VPN, management, legacy ALB, legacy DB Secret, legacy On-Prem
access key, old EKS version, and old PostgreSQL label resources are
intentionally excluded.

## Node Labels

| Label | Purpose |
| --- | --- |
| `Internet` | External origin for public attack paths |
| `VPC`, `Subnet` | AWS network grouping |
| `ALB` | Public application load balancer, `HTTP/80` |
| `EKSCluster`, `Pod`, `ServiceAccount` | Kubernetes runtime and identity |
| `IAMUser`, `IAMRole`, `IAMPolicy` | AWS identity and permission structure |
| `Credential`, `IAMAccessKey` | Access keys and credential-like material |
| `S3Bucket`, `LogPrefix` | Data/log buckets and configured prefixes |
| `RDS`, `SecretsManager`, `KMSKey` | Data stores, secrets, and encryption keys |
| `Scenario`, `Finding`, `Event` | Analysis metadata and detection evidence |

## Relationship Types

| Type | Meaning |
| --- | --- |
| `CONTAINS` | Parent infrastructure contains a child resource |
| `EXPOSED_TO_INTERNET` | Public entry point exists |
| `ALLOWS_TRAFFIC` | Network flow is allowed |
| `CAN_MOVE_TO` | Attack movement is feasible |
| `CONNECTS_TO` | Runtime/application connection |
| `RUNS_ON` | Pod runs on EKS |
| `USES_SERVICE_ACCOUNT` | Pod uses a Kubernetes ServiceAccount |
| `IRSA_LINKED_TO` | ServiceAccount can assume an IAM role via IRSA |
| `HAS_CREDENTIAL` | Identity or host stores/owns a credential |
| `AUTHENTICATES_AS` | Credential authenticates as an IAM identity |
| `ASSUMES_ROLE` | IAM identity can assume a role |
| `HAS_PERMISSION` | Identity, role, or credential is associated with a policy |
| `CAN_ACCESS` | Policy grants access to a target resource or KMS key |
| `ENCRYPTED_BY` | Resource is encrypted with a KMS key |
| `LOGS_TO`, `HAS_LOG_PREFIX` | Log delivery destination and prefix |
| `MATCHES_SCENARIO` | Event evidence is associated with a scenario |
| `HAS_FINDING` | Asset, credential, or runtime node has a scanner/security finding |

## Attack Path Model

### S1-A

`hap-dev-01-access-key` authenticates as `hap-dev-01-user`, which has direct
`hap-s3-access-policy` access to `hap-customer-data-s3`. The policy also has
`kms:Decrypt` access to `hap-data-cmk` because the bucket is SSE-KMS encrypted.

### S1-B

`hap-dev-01-access-key` authenticates as `hap-dev-01-user`, the user assumes
`hap-s3-readonly-role`, and `hap-s3-readonly-policy` grants customer S3 read
access plus required KMS decrypt capability.

### S2

`internet` reaches `hap-prod-alb` on `HTTP/80`; the ALB can move to
`pod-gitea-app`; the Pod runs in Kubernetes namespace `prod`, pulls its image
from `hap-ecr`, and connects to `hap-gitea-db`.

### S3

`hap-onprem-web` has `hap-onprem-web-key`. The key/policy can write only:

| Bucket | Prefix | Permission |
| --- | --- | --- |
| `hap-customer-data-s3` | `wordpress-files/` | `s3:PutObject` |
| `hap-customer-data-s3` | `wordpress-db/` | `s3:PutObject` |
| `hap-soc-log-s3` | `onprem/` | `s3:PutObject` |

`hap-onprem-web-key` authenticates as `hap-onprem-web-user`, not
`hap-dev-01-user`.

`hap-onprem-db` has `hap-onprem-db-key`, but that key is log-only through
`hap-onprem-db-s3-policy` and has no path to `hap-customer-data-s3`.

### S4

`pod-gitea-app` uses `gitea-sa` in namespace `prod`; IRSA links the
ServiceAccount to `hap-irsa-gitea-role` with subject
`system:serviceaccount:prod:gitea-sa`; `hap-gitea-role-policy` grants
`secretsmanager:GetSecretValue` on `gitea-db-credentials` and `kms:Decrypt` on
`hap-prod-secrets-cmk`; the Secret connects to `hap-gitea-db`.

## Dynamic Attack Path Model

`GET /dynamic-attack-paths` searches the current Neo4j graph rather than the
fixed `SCENARIOS` list. The fixed S1-A, S1-B, S2, S3, and S4 scenario queries
remain unchanged.

Default source labels are `Internet`, `Credential`, `IAMAccessKey`, `IAMUser`,
`Pod`, `ALB`, `OnPremWeb`, and `OnPremDB`.

Default targets are nodes with `sensitive=true` or labels `S3Bucket`, `RDS`,
`SecretsManager`, `KMSKey`, or `ECRRepository`.

The dynamic traversal allows only attack movement or permission relationships:
`EXPOSED_TO_INTERNET`, `ALLOWS_TRAFFIC`, `CAN_MOVE_TO`, `CONNECTS_TO`,
`HAS_CREDENTIAL`, `HAS_ACCESS_KEY`, `AUTHENTICATES_AS`, `ASSUMES_ROLE`,
`USES_SERVICE_ACCOUNT`, `IRSA_LINKED_TO`, `HAS_PERMISSION`, `CAN_ACCESS`,
`CAN_ACCESS_SECRET`, and `PULLS_IMAGE_FROM`.

Metadata relationships such as `CONTAINS`, `LOGS_TO`, `HAS_FINDING`, and
`ENCRYPTED_BY` are excluded from traversal. Paths are directional, require at
least one hop, reject repeated-node cycles, and default to depth `8` with an
allowed range of `1` through `12`. Candidate paths are over-fetched up to a
bounded cap, then deduplicated, scored, sorted by risk descending and hop count
ascending, and limited in Python.

## Detection Event Model

## Risk Score Model

`app/path_finder.py` computes a 0-10 score. Existing response fields are
preserved, and `riskBreakdown` plus `findingSummary` explain why a path scored
the way it did.

| Component | Max contribution | Basis |
| --- | ---: | --- |
| `assetSensitivity` | 2.0 | target sensitivity, sensitive flag, and target labels such as S3/RDS/Secret/KMS |
| `internetExposure` | 1.2 | `EXPOSED_TO_INTERNET` relationship or exposed node flag |
| `permissionRisk` | 2.0 | credential use, assume role/IRSA, policy access, wildcard actions |
| `hopRisk` | 1.0 | shorter paths score higher |
| `findingRisk` | 2.5 | active TRIVY/SCOUT_SUITE findings connected to path nodes |

Finding scoring uses severity weights (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`,
`UNKNOWN`) and CVSS when present. Duplicate CVEs are counted once, only the top
five active findings contribute, `RESOLVED` and `SUPPRESSED` are excluded, and
the final score is capped at `10.0`.

The API returns:

```text
riskScore
riskLevel
riskBreakdown.assetSensitivity
riskBreakdown.internetExposure
riskBreakdown.permissionRisk
riskBreakdown.hopRisk
riskBreakdown.findingRisk
findingSummary.total
findingSummary.critical
findingSummary.high
findingSummary.medium
findingSummary.low
findingSummary.maxCvss
findingSummary.sources
```

## Scenario Status Model

| Status | Meaning |
| --- | --- |
| `REPRODUCED` | Attack has been reproduced and has supporting logs |
| `DETECTABLE` | Detection rule exists, but no current matching Event is required |
| `DETECTED` | Current Event nodes match a detection rule |
| `POTENTIAL` | Asset, credential, permission, or network graph path exists |

S1-S4 are graph-derived and seeded as `POTENTIAL`. Detection rules are exposed
as `DETECTABLE` and become `DETECTED` in API output when matching events exist.

`scripts/detection-rules.cypher` assumes `Event` nodes with these common
properties:

```text
event_id, event_time, source_type, log_type, actor_id, actor_type, source_ip,
action, source_asset_id, target_asset_id, result, severity_hint, raw_log_ref,
access_key_id, credential_id, request_id, session_id, role_arn, service_account,
pod_id, secret_arn, kms_key_id, bucket_name, object_key, resource_prefix,
database_user, attributes
```

The minimal evidence relationships are:

```text
Event -[:PERFORMED_BY]-> Identity
Event -[:ORIGINATED_FROM]-> Asset
Event -[:TARGETED]-> Asset
Event -[:USES_CREDENTIAL]-> Credential
Event -[:MATCHES_SCENARIO]-> Scenario
```

Current detection rules cover:

| Rule | Scenario |
| --- | --- |
| D1 | IAM access key used from an unusual IP or region |
| D2 | Repeated AssumeRole in a short time window |
| D3 | AssumeRole followed by customer S3 ListBucket/GetObject |
| D4 | S3 PutObject outside allowed prefixes |
| D5 | WordPress compromise followed by hap-onprem-web-key use |
| D6 | Unexpected GetSecretValue from Pod |
| D7 | GetSecretValue followed by KMS Decrypt and RDS access |
| D8 | Abnormal Pod behavior after internal ALB attack |
| D9 | Unexpected direct RDS access from Pod |
| D10 | DB log-only credential attempts customer S3 access |
| D11 | Repeated AccessDenied |
| D12 | AWS API calls from unusual User-Agent |

Each scenario query returns the common detection result fields:
`scenario_id`, `scenario_name`, `severity`, `first_event_time`,
`last_event_time`, `evidence_count`, `event_ids`, `source_asset_id`,
`target_asset_id`, `credential_id`, `actor_id`, and `graph_node_ids`.
