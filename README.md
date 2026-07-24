# Hybrid Attack Path Backend1

Backend1 models hybrid attack paths as a Neo4j graph and validates the paths
with executable Cypher. The current graph is aligned with the latest
`origin/feature/infra1-terraform-base` infrastructure resources inspected for
this task.

## APIs

```text
GET /health
GET /scenarios
GET /attack-paths
GET /attack-paths/{scenario_id}
GET /cytoscape
GET /detections
GET /detection-rules
GET /dynamic-attack-paths
```

## Dynamic Attack Paths

`GET /dynamic-attack-paths` discovers attack paths directly from the current
Neo4j graph without adding entries to the fixed `SCENARIOS` list. It keeps the
existing S1-A, S1-B, S2, S3, and S4 APIs unchanged.

Default sources are nodes labelled `Internet`, `Credential`, `IAMAccessKey`,
`IAMUser`, `Pod`, `ALB`, `OnPremWeb`, or `OnPremDB`. Default targets are
`sensitive=true` nodes or nodes labelled `S3Bucket`, `RDS`, `SecretsManager`,
`KMSKey`, or `ECRRepository`.

Allowed traversal relationships are attack movement or permission edges:
`EXPOSED_TO_INTERNET`, `ALLOWS_TRAFFIC`, `CAN_MOVE_TO`, `CONNECTS_TO`,
`HAS_CREDENTIAL`, `HAS_ACCESS_KEY`, `AUTHENTICATES_AS`, `ASSUMES_ROLE`,
`USES_SERVICE_ACCOUNT`, `IRSA_LINKED_TO`, `HAS_PERMISSION`, `CAN_ACCESS`,
`CAN_ACCESS_SECRET`, and `PULLS_IMAGE_FROM`. Non-attack metadata edges such as
`CONTAINS`, `LOGS_TO`, `HAS_FINDING`, and `ENCRYPTED_BY` are excluded.

Query parameters:

```text
maxDepth      default 8, min 1, max 12
limit         default 100, min 1, max 200
sourceId      optional exact source node id
targetId      optional exact target node id
minRiskScore  default 0, min 0, max 10
```

Examples:

```powershell
curl -sS "http://127.0.0.1:8000/dynamic-attack-paths"
curl -sS "http://127.0.0.1:8000/dynamic-attack-paths?maxDepth=8&limit=100"
curl -sS "http://127.0.0.1:8000/dynamic-attack-paths?sourceId=internet&targetId=hap-gitea-db&maxDepth=8"
curl -sS "http://127.0.0.1:8000/dynamic-attack-paths?minRiskScore=6&limit=50"
```

Dynamic results are scored with the same risk and finding logic used by fixed
attack paths. Candidate paths are fetched above the requested `limit`, then
deduplicated, scored, sorted by `riskScore` descending and `hopCount`
ascending, and finally limited in Python.

## Current Infrastructure Baseline

| Area | Final value |
| --- | --- |
| EKS cluster | `hap-eks`, Kubernetes `1.33` |
| Prod ALB | `hap-prod-alb` |
| Prod ALB listener | `HTTP/80` |
| Gitea Pod | `pod-gitea-app` |
| Gitea Pod namespace | `prod` |
| ServiceAccount | `gitea-sa` |
| ServiceAccount namespace | `prod` |
| IRSA subject | `system:serviceaccount:prod:gitea-sa` |
| IRSA role | `hap-irsa-gitea-role` |
| IRSA policy | `hap-gitea-role-policy` |
| ECR repository | `hap-ecr` |
| RDS | `hap-gitea-db`, PostgreSQL `16` |
| K8s mounted DB Secret | `gitea-db-credentials` |
| AWS Secrets Manager source | `hap-db-secret` |
| Customer data S3 | `hap-customer-data-s3`, SSE-KMS via `hap-data-cmk` |
| General SOC log S3 | `hap-soc-log-s3`, SSE-KMS via `hap-log-cmk`, Object Lock |
| ALB/AWS Config log S3 | `hap-soc-alb-log-s3`, SSE-S3 |
| Prod ALB log prefix | `prod-alb/` |
| AWS Config prefix | `config/` under `hap-soc-alb-log-s3` |
| On-Prem log prefix | `onprem/` under `hap-soc-log-s3` |

The graph intentionally omits the previously removed cache, VPN, management,
legacy ALB, legacy DB Secret, legacy On-Prem access key, old PostgreSQL label,
old data-event prefix, and old EKS version references.

## Final Attack Paths

### S1-A: dev-01 direct IAM policy

```text
hap-dev-01-access-key
  -> AUTHENTICATES_AS
hap-dev-01-user
  -> HAS_PERMISSION
hap-s3-access-policy
  -> CAN_ACCESS
hap-customer-data-s3
```

Because `hap-customer-data-s3` uses SSE-KMS, the policy also links to
`hap-data-cmk` with `kms:Decrypt`.

### S1-B: dev-01 assumes readonly role

```text
hap-dev-01-access-key
  -> AUTHENTICATES_AS
hap-dev-01-user
  -> ASSUMES_ROLE
hap-s3-readonly-role
  -> HAS_PERMISSION
hap-s3-readonly-policy
  -> CAN_ACCESS
hap-customer-data-s3
```

S1 detection rules are implemented but marked conceptually as pending sample
validation because final log samples are not yet available.

### S2: Internet to Gitea/RDS

```text
internet
  -> EXPOSED_TO_INTERNET
hap-prod-alb
  -> CAN_MOVE_TO
pod-gitea-app
  -> CONNECTS_TO
hap-gitea-db
```

`hap-prod-alb` uses `HTTP/80`; no TLS listener is modeled for the current graph.
`pod-gitea-app` runs in the Kubernetes `prod` namespace and pulls its image
from `hap-ecr`.

### S3: On-Prem WordPress key to prefix-limited S3

```text
hap-onprem-web
  -> HAS_CREDENTIAL
hap-onprem-web-key
  -> HAS_PERMISSION
hap-onprem-web-s3-policy
  -> CAN_ACCESS
hap-customer-data-s3
```

Customer-data access is prefix-limited to `wordpress-files/` and
`wordpress-db/`. Log upload access is prefix-limited to `onprem/` in
`hap-soc-log-s3`.

There is no `AUTHENTICATES_AS` relationship from `hap-onprem-web-key` to
`hap-dev-01-user`.

### On-Prem DB log-only path

```text
hap-onprem-db
  -> HAS_CREDENTIAL
hap-onprem-db-key
  -> HAS_PERMISSION
hap-onprem-db-s3-policy
  -> CAN_ACCESS
hap-soc-log-s3
```

The DB key has no path to `hap-customer-data-s3`.

### S4: Gitea Pod IRSA to Secret/RDS

```text
pod-gitea-app
  -> USES_SERVICE_ACCOUNT
gitea-sa
  -> IRSA_LINKED_TO
hap-irsa-gitea-role
  -> HAS_PERMISSION
hap-gitea-role-policy
  -> CAN_ACCESS
gitea-db-credentials
  -> CONNECTS_TO
hap-gitea-db
```

The graph uses `gitea-db-credentials` as the mounted Secret node ID and stores
`awsSecretName: hap-db-secret` on that node to preserve the Terraform/K8s
mapping. The ServiceAccount namespace is `prod`, and the IRSA trust subject is
`system:serviceaccount:prod:gitea-sa`.

## Risk Score

The API keeps the existing `riskScore` and `riskLevel` fields and adds a
non-breaking explanation payload:

```json
{
  "riskScore": 7.4,
  "riskLevel": "HIGH",
  "riskBreakdown": {
    "assetSensitivity": 2.0,
    "internetExposure": 1.2,
    "permissionRisk": 2.0,
    "hopRisk": 0.7,
    "findingRisk": 1.5
  },
  "findingSummary": {
    "total": 2,
    "critical": 1,
    "high": 1,
    "medium": 0,
    "low": 0,
    "maxCvss": 9.8,
    "sources": ["TRIVY", "SCOUT_SUITE"]
  }
}
```

`findingRisk` is based on active `Finding` nodes connected through
`HAS_FINDING` to any node in the returned path. `RESOLVED` and `SUPPRESSED`
findings are excluded, duplicate CVEs are counted once, only the strongest five
findings contribute to the score, and `findingRisk` is capped at `2.5`. The
overall score remains capped at `10.0`.

Scenario status values are `REPRODUCED`, `DETECTABLE`, `DETECTED`, and
`POTENTIAL`. S1-S4 are seeded as `POTENTIAL`; detection rules return `DETECTED`
when matching `Event` evidence exists and `DETECTABLE` otherwise.

## Detection Rules

`scripts/detection-rules.cypher` and the `/detection-rules` endpoint expose D1
through D12:

```text
D1  unusual IP/region IAM access key usage
D2  repeated AssumeRole
D3  AssumeRole followed by customer S3 read
D4  S3 PutObject outside allowed prefixes
D5  WordPress compromise followed by hap-onprem-web-key use
D6  unexpected GetSecretValue from Pod
D7  GetSecretValue followed by KMS Decrypt and RDS access
D8  abnormal Pod behavior after ALB attack
D9  unexpected direct RDS access from Pod
D10 DB log-only credential attempts customer S3 access
D11 repeated AccessDenied
D12 unusual User-Agent AWS API calls
```

## Files

```text
scripts/seed.cypher
scripts/attack-path-queries.cypher
scripts/detection-rules.cypher
app/dynamic_path_finder.py
docs/backend1-neo4j-design.md
README.md
```

## Run Locally

Start Neo4j:

```powershell
docker start hybrid-neo4j
Start-Sleep -Seconds 15
```

Load the seed:

```powershell
docker cp .\scripts\seed.cypher hybrid-neo4j:/seed.cypher
docker exec hybrid-neo4j cypher-shell -u neo4j -p password1234 -f /seed.cypher
```

Run path queries:

```powershell
docker cp .\scripts\attack-path-queries.cypher hybrid-neo4j:/attack-path-queries.cypher
docker exec hybrid-neo4j cypher-shell -u neo4j -p password1234 -f /attack-path-queries.cypher
```

Run detection rule syntax checks:

```powershell
docker cp .\scripts\detection-rules.cypher hybrid-neo4j:/detection-rules.cypher
docker exec hybrid-neo4j cypher-shell -u neo4j -p password1234 -f /detection-rules.cypher
```

## Useful Validation Queries

```cypher
MATCH (n {id: "hap-prod-alb"}) RETURN n.id, n.protocol, n.port;
MATCH (n {id: "gitea-db-credentials"}) RETURN n.id, n.awsSecretName, n.k8sSecretName;
MATCH (n {id: "hap-eks"}) RETURN n.id, n.version;
MATCH (n) WHERE (n:Pod OR n:ServiceAccount) AND n.namespace = "gitea" RETURN count(n);
MATCH (n:ECRRepository {id: "hap-gitea-ecr"}) RETURN count(n);
MATCH (:Pod {id: "pod-gitea-app"})-[r:PULLS_IMAGE_FROM]->(:ECRRepository {id: "hap-ecr"}) RETURN count(r);
MATCH (pod:Pod {id: "pod-gitea-app"}), (sa:ServiceAccount {id: "gitea-sa"}) RETURN pod.namespace, sa.namespace, sa.irsaSubject;
MATCH (n)-[r]->(m) RETURN type(r), count(*) ORDER BY type(r);
```
