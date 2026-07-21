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
| ServiceAccount | `gitea-sa` |
| IRSA role | `hap-irsa-gitea-role` |
| IRSA policy | `hap-gitea-role-policy` |
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
`pod-gitea-app`; the Pod connects to `hap-gitea-db`.

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

`pod-gitea-app` uses `gitea-sa`; IRSA links the ServiceAccount to
`hap-irsa-gitea-role`; `hap-gitea-role-policy` grants
`secretsmanager:GetSecretValue` on `gitea-db-credentials` and `kms:Decrypt` on
`hap-prod-secrets-cmk`; the Secret connects to `hap-gitea-db`.

## Detection Event Model

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
| R1 | S2 abnormal ALB/Pod/RDS chain |
| R2 | S3 On-Prem web key writing customer S3 backup prefixes |
| R3 | S3 On-Prem web key writing SOC log prefix |
| R4 | S4 AssumeRoleWithWebIdentity, GetSecretValue, optional KMS decrypt, RDS |
| R5 | S1-A dev-01 key direct customer S3 access |
| R6 | S1-B dev-01 key AssumeRole then customer S3 read |

Each scenario query returns the common detection result fields:
`scenario_id`, `scenario_name`, `severity`, `first_event_time`,
`last_event_time`, `evidence_count`, `event_ids`, `source_asset_id`,
`target_asset_id`, `credential_id`, `actor_id`, and `graph_node_ids`.
