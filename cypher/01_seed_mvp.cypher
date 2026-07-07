// ============================================================
// SOC VPC - 우리 시스템 영역
// ============================================================

MERGE (:Asset:Network {
  id: 'vpc-soc',
  label: 'SOC VPC',
  type: 'VPC',
  environment: 'SOC',
  assetRole: 'SYSTEM',
  sensitivityLevel: 'INTERNAL',
  riskLevel: 'MEDIUM'
});

MERGE (:Asset:Server {
  id: 'ec2-neo4j-engine',
  label: 'Neo4j + Attack Path Engine Server',
  type: 'NEO4J_ENGINE_SERVER',
  environment: 'SOC',
  assetRole: 'SYSTEM',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Server {
  id: 'ec2-collector-scanner',
  label: 'Collector / Scanner Server',
  type: 'COLLECTOR_SCANNER_SERVER',
  environment: 'SOC',
  assetRole: 'SYSTEM',
  sensitivityLevel: 'INTERNAL',
  riskLevel: 'MEDIUM'
});

MERGE (:Asset:Server {
  id: 'ec2-api-front',
  label: 'API + Frontend Server',
  type: 'API_FRONT_SERVER',
  environment: 'SOC',
  assetRole: 'SYSTEM',
  sensitivityLevel: 'INTERNAL',
  riskLevel: 'MEDIUM'
});

MATCH (soc:Asset {id: 'vpc-soc'})
MATCH (engine:Asset {id: 'ec2-neo4j-engine'})
MERGE (engine)-[:BELONGS_TO {id: 'rel-engine-belongs-soc'}]->(soc);

MATCH (soc:Asset {id: 'vpc-soc'})
MATCH (collector:Asset {id: 'ec2-collector-scanner'})
MERGE (collector)-[:BELONGS_TO {id: 'rel-collector-belongs-soc'}]->(soc);

MATCH (soc:Asset {id: 'vpc-soc'})
MATCH (api:Asset {id: 'ec2-api-front'})
MERGE (api)-[:BELONGS_TO {id: 'rel-api-belongs-soc'}]->(soc);


// ============================================================
// PROD VPC - 분석 대상 영역
// ============================================================

MERGE (:Asset:Network {
  id: 'vpc-prod',
  label: 'Prod VPC',
  type: 'VPC',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'INTERNAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Network {
  id: 'internet',
  label: 'Internet',
  type: 'INTERNET',
  environment: 'EXTERNAL',
  assetRole: 'EXTERNAL',
  sensitivityLevel: 'PUBLIC',
  riskLevel: 'HIGH'
});

MATCH (soc:Asset {id: 'vpc-soc'})
MATCH (prod:Asset {id: 'vpc-prod'})
MERGE (soc)-[:PEERED_WITH {id: 'rel-soc-prod-peering'}]->(prod);


// ============================================================
// Gitea / RDS / Redis / ECR / Secrets Manager
// ============================================================

MERGE (:Asset:Server {
  id: 'app-gitea',
  label: 'Gitea Application',
  type: 'GITEA_APP',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Database {
  id: 'rds-postgres-prod',
  label: 'RDS PostgreSQL',
  type: 'RDS_POSTGRESQL',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Cache {
  id: 'elasticache-redis-prod',
  label: 'ElastiCache Redis',
  type: 'ELASTICACHE_REDIS',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Repository {
  id: 'ecr-gitea-image',
  label: 'ECR Gitea Image Repository',
  type: 'ECR_REPOSITORY',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'INTERNAL',
  riskLevel: 'MEDIUM'
});

MERGE (:Asset:Secret {
  id: 'secret-gitea-db-password',
  label: 'Gitea DB Password Secret',
  type: 'SECRETS_MANAGER',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Key {
  id: 'kms-secrets-key',
  label: 'KMS Key for Secrets Manager',
  type: 'KMS_KEY',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Storage {
  id: 'hap-customer-data-s3',
  label: 'HAP Customer Dummy Data S3',
  type: 'S3_BUCKET',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MATCH (internet:Asset {id: 'internet'})
MATCH (gitea:Asset {id: 'app-gitea'})
MERGE (internet)-[:EXPOSED_TO_INTERNET {id: 'rel-internet-gitea'}]->(gitea);

MATCH (gitea:Asset {id: 'app-gitea'})
MATCH (rds:Asset {id: 'rds-postgres-prod'})
MERGE (gitea)-[:CONNECTS_TO_DB {id: 'rel-gitea-rds'}]->(rds);

MATCH (gitea:Asset {id: 'app-gitea'})
MATCH (redis:Asset {id: 'elasticache-redis-prod'})
MERGE (gitea)-[:USES_CACHE {id: 'rel-gitea-redis'}]->(redis);


// ============================================================
// EKS Pod - IRSA - Secrets Manager 경로
// ============================================================

MERGE (:Asset:Container {
  id: 'eks-pod-gitea',
  label: 'Gitea EKS Pod',
  type: 'EKS_POD',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Kubernetes {
  id: 'k8s-sa-gitea',
  label: 'Gitea ServiceAccount',
  type: 'SERVICE_ACCOUNT',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Identity {
  id: 'irsa-gitea-role',
  label: 'IRSA Gitea IAM Role',
  type: 'IAM_ROLE',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Policy {
  id: 'iam-policy-gitea-secrets-access',
  label: 'Gitea Secrets Access Policy',
  type: 'IAM_POLICY',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MATCH (pod:Asset {id: 'eks-pod-gitea'})
MATCH (sa:Asset {id: 'k8s-sa-gitea'})
MERGE (pod)-[:USES_SERVICE_ACCOUNT {id: 'rel-pod-uses-sa'}]->(sa);

MATCH (sa:Asset {id: 'k8s-sa-gitea'})
MATCH (role:Asset {id: 'irsa-gitea-role'})
MERGE (sa)-[:IRSA_LINKED_TO {id: 'rel-sa-irsa-role'}]->(role);

MATCH (role:Asset {id: 'irsa-gitea-role'})
MATCH (policy:Asset {id: 'iam-policy-gitea-secrets-access'})
MERGE (role)-[:HAS_POLICY {id: 'rel-role-has-secrets-policy'}]->(policy);

MATCH (policy:Asset {id: 'iam-policy-gitea-secrets-access'})
MATCH (secret:Asset {id: 'secret-gitea-db-password'})
MERGE (policy)-[:HAS_PERMISSION {
  id: 'rel-policy-can-read-secret',
  action: 'secretsmanager:GetSecretValue'
}]->(secret);

MATCH (policy:Asset {id: 'iam-policy-gitea-secrets-access'})
MATCH (kms:Asset {id: 'kms-secrets-key'})
MERGE (policy)-[:HAS_PERMISSION {
  id: 'rel-policy-can-decrypt-kms',
  action: 'kms:Decrypt'
}]->(kms);

MATCH (secret:Asset {id: 'secret-gitea-db-password'})
MATCH (rds:Asset {id: 'rds-postgres-prod'})
MERGE (secret)-[:STORES_CREDENTIAL_FOR {id: 'rel-secret-for-rds'}]->(rds);


// ============================================================
// On-Prem 최소 유지 - Access Key 기반 하이브리드 시나리오
// ============================================================

MERGE (:Asset:Server {
  id: 'onprem-admin-server',
  label: 'On-Prem Admin Server',
  type: 'ON_PREM_SERVER',
  environment: 'ON_PREM',
  assetRole: 'TARGET',
  sensitivityLevel: 'CONFIDENTIAL',
  riskLevel: 'HIGH'
});

MERGE (:Asset:Credential {
  id: 'aws-access-key-dev-01',
  label: 'Stored AWS Access Key',
  type: 'AWS_ACCESS_KEY',
  environment: 'ON_PREM',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Identity {
  id: 'iam-user-dev-01',
  label: 'Developer IAM User',
  type: 'IAM_USER',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MERGE (:Asset:Policy {
  id: 'iam-policy-prod-read',
  label: 'Prod Read Access Policy',
  type: 'IAM_POLICY',
  environment: 'PROD',
  assetRole: 'TARGET',
  sensitivityLevel: 'RESTRICTED',
  riskLevel: 'CRITICAL'
});

MATCH (onprem:Asset {id: 'onprem-admin-server'})
MATCH (key:Asset {id: 'aws-access-key-dev-01'})
MERGE (onprem)-[:STORES_CREDENTIAL {id: 'rel-onprem-stores-access-key'}]->(key);

MATCH (key:Asset {id: 'aws-access-key-dev-01'})
MATCH (user:Asset {id: 'iam-user-dev-01'})
MERGE (key)-[:BELONGS_TO {id: 'rel-key-belongs-iam-user'}]->(user);

MATCH (user:Asset {id: 'iam-user-dev-01'})
MATCH (policy:Asset {id: 'iam-policy-prod-read'})
MERGE (user)-[:HAS_POLICY {id: 'rel-user-has-prod-read-policy'}]->(policy);

MATCH (policy:Asset {id: 'iam-policy-prod-read'})
MATCH (s3:Asset {id: 'hap-customer-data-s3'})
MERGE (policy)-[:HAS_PERMISSION {
  id: 'rel-policy-can-read-customer-s3',
  action: 's3:GetObject'
}]->(s3);

MATCH (policy:Asset {id: 'iam-policy-prod-read'})
MATCH (secret:Asset {id: 'secret-gitea-db-password'})
MERGE (policy)-[:HAS_PERMISSION {
  id: 'rel-policy-can-read-gitea-secret',
  action: 'secretsmanager:GetSecretValue'
}]->(secret);

MATCH (policy:Asset {id: 'iam-policy-prod-read'})
MATCH (ecr:Asset {id: 'ecr-gitea-image'})
MERGE (policy)-[:HAS_PERMISSION {
  id: 'rel-policy-can-read-ecr',
  action: 'ecr:BatchGetImage'
}]->(ecr);