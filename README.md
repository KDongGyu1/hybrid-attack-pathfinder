# Hybrid Attack Path Backend1

Backend1 models hybrid attack paths as a Neo4j graph and validates the paths
with executable Cypher. The current graph is aligned with the latest
`origin/feature/infra1-terraform-base` infrastructure resources inspected for
this task.

## Current Infrastructure Baseline

| Area | Final value |
| --- | --- |
| EKS cluster | `hap-eks`, Kubernetes `1.33` |
| Prod ALB | `hap-prod-alb` |
| Prod ALB listener | `HTTP/80` |
| Gitea Pod | `pod-gitea-app` |
| ServiceAccount | `gitea-sa` |
| IRSA role | `hap-irsa-gitea-role` |
| IRSA policy | `hap-gitea-role-policy` |
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
mapping.

## Files

```text
scripts/seed.cypher
scripts/attack-path-queries.cypher
scripts/detection-rules.cypher
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
MATCH (n)-[r]->(m) RETURN type(r), count(*) ORDER BY type(r);
```
