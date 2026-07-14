// =====================================================
// Hybrid Attack Path Backend1
// Neo4j Seed Data
// Final identity / credential structure aligned
//
// 주의: 아래 초기화 쿼리는 현재 Neo4j 그래프를 전체 삭제한다.
// 로컬 검증 환경에서 실행한다.
// =====================================================

MATCH (n)
DETACH DELETE n;

// =====================================================
// Core Infrastructure Nodes
// =====================================================

MERGE (internet:Internet {id: "internet"})
SET internet.name = "Internet",
    internet.displayName = "External Attacker / Internet",
    internet.type = "Internet";

MERGE (socVpc:VPC {id: "hap-soc-vpc"})
SET socVpc.name = "hap-soc-vpc",
    socVpc.displayName = "SOC VPC",
    socVpc.type = "VPC",
    socVpc.environment = "soc",
    socVpc.provider = "AWS";

MERGE (prodVpc:VPC {id: "hap-prod-vpc"})
SET prodVpc.name = "hap-prod-vpc",
    prodVpc.displayName = "Prod VPC",
    prodVpc.type = "VPC",
    prodVpc.environment = "prod",
    prodVpc.provider = "AWS";

MERGE (publicSubnet:Subnet {id: "hap-prod-public-subnet"})
SET publicSubnet.name = "hap-prod-public-subnet",
    publicSubnet.displayName = "Prod Public Subnet",
    publicSubnet.type = "Subnet",
    publicSubnet.subnetType = "public",
    publicSubnet.provider = "AWS";

MERGE (appSubnet:Subnet {id: "hap-prod-app-subnet"})
SET appSubnet.name = "hap-prod-app-subnet",
    appSubnet.displayName = "Prod Private App Subnet",
    appSubnet.type = "Subnet",
    appSubnet.subnetType = "private-app",
    appSubnet.provider = "AWS";

MERGE (dbSubnet:Subnet {id: "hap-prod-db-subnet"})
SET dbSubnet.name = "hap-prod-db-subnet",
    dbSubnet.displayName = "Prod Private DB Subnet",
    dbSubnet.type = "Subnet",
    dbSubnet.subnetType = "private-db",
    dbSubnet.provider = "AWS";

MERGE (prodAlb:ALB {id: "hap-public-web-alb"})
SET prodAlb.name = "hap-public-web-alb",
    prodAlb.displayName = "Prod Public Web ALB",
    prodAlb.type = "ALB",
    prodAlb.environment = "prod",
    prodAlb.exposed = true,
    prodAlb.provider = "AWS";

MERGE (eks:EKSCluster {id: "hap-eks-cluster"})
SET eks.name = "hap-eks-cluster",
    eks.displayName = "Prod EKS Cluster",
    eks.type = "EKSCluster",
    eks.provider = "AWS";

MERGE (pod:Pod {id: "pod-gitea-app"})
SET pod.name = "pod-gitea-app",
    pod.displayName = "Gitea Application Pod",
    pod.type = "Pod",
    pod.namespace = "default",
    pod.workload = "gitea";

MERGE (sa:ServiceAccount {id: "gitea-sa"})
SET sa.name = "gitea-sa",
    sa.displayName = "gitea-sa",
    sa.type = "ServiceAccount",
    sa.namespace = "default";

// =====================================================
// IAM User / Role / Policy Nodes
// =====================================================

MERGE (devUser:IAMUser {id: "hap-dev-01-user"})
SET devUser.name = "hap-dev-01-user",
    devUser.displayName = "hap-dev-01-user",
    devUser.type = "IAMUser",
    devUser.provider = "AWS";

MERGE (devAccessKey:Credential:IAMAccessKey {id: "hap-dev-01-access-key"})
SET devAccessKey.name = "hap-dev-01-access-key",
    devAccessKey.displayName = "Compromised hap-dev-01-user Access Key",
    devAccessKey.type = "IAMAccessKey",
    devAccessKey.provider = "AWS",
    devAccessKey.ownerIdentityId = "hap-dev-01-user",
    devAccessKey.compromised = true;

MERGE (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
SET s3ReadonlyRole.name = "hap-s3-readonly-role",
    s3ReadonlyRole.displayName = "hap-s3-readonly-role",
    s3ReadonlyRole.type = "IAMRole",
    s3ReadonlyRole.provider = "AWS";

MERGE (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"})
SET s3ReadonlyPolicy.name = "hap-s3-readonly-policy",
    s3ReadonlyPolicy.displayName = "hap-s3-readonly-policy",
    s3ReadonlyPolicy.type = "IAMPolicy",
    s3ReadonlyPolicy.provider = "AWS",
    s3ReadonlyPolicy.permission = "s3:ListBucket,s3:GetObject",
    s3ReadonlyPolicy.scope = "S1-path-B";

MERGE (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
SET irsaRole.name = "hap-irsa-gitea-role",
    irsaRole.displayName = "hap-irsa-gitea-role",
    irsaRole.type = "IAMRole",
    irsaRole.provider = "AWS";

MERGE (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
SET giteaRolePolicy.name = "hap-gitea-role-policy",
    giteaRolePolicy.displayName = "hap-gitea-role-policy",
    giteaRolePolicy.type = "IAMPolicy",
    giteaRolePolicy.provider = "AWS";

// =====================================================
// On-Prem Identity / Credential / Policy Nodes
// =====================================================

MERGE (onpremWeb:OnPremWeb:IAMIdentity {id: "hap-onprem-web"})
SET onpremWeb.name = "hap-onprem-web",
    onpremWeb.displayName = "On-Prem WordPress Web Server",
    onpremWeb.type = "OnPremWeb",
    onpremWeb.environment = "on-prem",
    onpremWeb.application = "WordPress";

MERGE (onpremDb:OnPremDB:IAMIdentity {id: "hap-onprem-db"})
SET onpremDb.name = "hap-onprem-db",
    onpremDb.displayName = "On-Prem MySQL Database",
    onpremDb.type = "OnPremDB",
    onpremDb.environment = "on-prem",
    onpremDb.engine = "MySQL";

MERGE (webKey:Credential:IAMAccessKey {id: "hap-onprem-web-key"})
SET webKey.name = "hap-onprem-web-key",
    webKey.displayName = "On-Prem Web IAM Access Key",
    webKey.type = "IAMAccessKey",
    webKey.provider = "AWS",
    webKey.ownerIdentityId = "hap-onprem-web",
    webKey.compromised = true;

MERGE (dbKey:Credential:IAMAccessKey {id: "hap-onprem-db-key"})
SET dbKey.name = "hap-onprem-db-key",
    dbKey.displayName = "On-Prem DB IAM Access Key",
    dbKey.type = "IAMAccessKey",
    dbKey.provider = "AWS",
    dbKey.ownerIdentityId = "hap-onprem-db",
    dbKey.compromised = false;

MERGE (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
SET webPolicy.name = "hap-onprem-web-s3-policy",
    webPolicy.displayName = "On-Prem Web S3 Policy",
    webPolicy.type = "IAMPolicy",
    webPolicy.provider = "AWS",
    webPolicy.permission = "s3:PutObject",
    webPolicy.scope = "prefix-restricted";

MERGE (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-log-policy"})
SET dbLogPolicy.name = "hap-onprem-db-log-policy",
    dbLogPolicy.displayName = "On-Prem DB Log Policy",
    dbLogPolicy.type = "IAMPolicy",
    dbLogPolicy.provider = "AWS",
    dbLogPolicy.permission = "s3:PutObject",
    dbLogPolicy.scope = "log-only";

// =====================================================
// Data / Service Nodes
// =====================================================

MERGE (customerS3:S3Bucket {id: "hap-customer-data-s3"})
SET customerS3.name = "hap-customer-data-s3",
    customerS3.displayName = "Customer Data S3",
    customerS3.type = "S3Bucket",
    customerS3.provider = "AWS",
    customerS3.environment = "prod",
    customerS3.purpose = "customer-data",
    customerS3.sensitive = true;

MERGE (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
SET socLogS3.name = "hap-soc-log-s3",
    socLogS3.displayName = "SOC Audit and Collection Log Bucket",
    socLogS3.type = "S3Bucket",
    socLogS3.provider = "AWS",
    socLogS3.environment = "soc",
    socLogS3.purpose = "audit-and-collection-logs",
    socLogS3.encryption = "SSE-KMS",
    socLogS3.objectLock = true;

MERGE (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
SET socAlbLogS3.name = "hap-soc-alb-log-s3",
    socAlbLogS3.displayName = "SOC ALB Access Log Bucket",
    socAlbLogS3.type = "S3Bucket",
    socAlbLogS3.provider = "AWS",
    socAlbLogS3.environment = "soc",
    socAlbLogS3.purpose = "alb-access-logs",
    socAlbLogS3.encryption = "SSE-S3",
    socAlbLogS3.objectLock = false,
    socAlbLogS3.prodPrefix = "prod-alb/",
    socAlbLogS3.socPrefix = "soc-alb/";

MERGE (rds:RDS {id: "hap-gitea-db"})
SET rds.name = "hap-gitea-db",
    rds.displayName = "Gitea RDS PostgreSQL",
    rds.type = "RDS",
    rds.engine = "PostgreSQL",
    rds.engineVersion = "16",
    rds.provider = "AWS",
    rds.sensitive = true;

MERGE (secret:SecretsManager {id: "hap-gitea-db-secret"})
SET secret.name = "hap-gitea-db-secret",
    secret.displayName = "Gitea DB Credential Secret",
    secret.type = "SecretsManager",
    secret.provider = "AWS",
    secret.secretType = "db-credential",
    secret.sensitive = true;

MERGE (ecr:ECRRepository {id: "hap-gitea-ecr"})
SET ecr.name = "hap-gitea-ecr",
    ecr.displayName = "Gitea ECR Repository",
    ecr.type = "ECRRepository",
    ecr.provider = "AWS";

MERGE (cw:CloudWatchLog {id: "hap-gitea-cloudwatch-log"})
SET cw.name = "hap-gitea-cloudwatch-log",
    cw.displayName = "Gitea CloudWatch Log",
    cw.type = "CloudWatchLog",
    cw.provider = "AWS";

MERGE (kms:KMSKey {id: "hap-kms-key"})
SET kms.name = "hap-kms-key",
    kms.displayName = "KMS Key",
    kms.type = "KMSKey",
    kms.provider = "AWS";

// =====================================================
// Finding Nodes
// =====================================================

MERGE (findingAlb:Finding {id: "finding-alb-public-exposure"})
SET findingAlb.name = "finding-alb-public-exposure",
    findingAlb.displayName = "ALB is exposed to the Internet",
    findingAlb.type = "Finding",
    findingAlb.severity = "MEDIUM";

MERGE (findingWebKey:Finding {id: "finding-onprem-web-key-exposure"})
SET findingWebKey.name = "finding-onprem-web-key-exposure",
    findingWebKey.displayName = "Web IAM Access Key stored on WordPress server",
    findingWebKey.type = "Finding",
    findingWebKey.severity = "HIGH";

MERGE (findingDevKey:Finding {id: "finding-dev-access-key-exposure"})
SET findingDevKey.name = "finding-dev-access-key-exposure",
    findingDevKey.displayName = "IAM User Access Key compromised",
    findingDevKey.type = "Finding",
    findingDevKey.severity = "HIGH";

// =====================================================
// Containment
// =====================================================

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (publicSubnet:Subnet {id: "hap-prod-public-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(publicSubnet);

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (appSubnet:Subnet {id: "hap-prod-app-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(appSubnet);

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (dbSubnet:Subnet {id: "hap-prod-db-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(dbSubnet);

MATCH (publicSubnet:Subnet {id: "hap-prod-public-subnet"}), (prodAlb:ALB {id: "hap-public-web-alb"})
MERGE (publicSubnet)-[:CONTAINS]->(prodAlb);

MATCH (appSubnet:Subnet {id: "hap-prod-app-subnet"}), (eks:EKSCluster {id: "hap-eks-cluster"})
MERGE (appSubnet)-[:CONTAINS]->(eks);

MATCH (dbSubnet:Subnet {id: "hap-prod-db-subnet"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (dbSubnet)-[:CONTAINS]->(rds);

MATCH (socVpc:VPC {id: "hap-soc-vpc"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socLogS3);

MATCH (socVpc:VPC {id: "hap-soc-vpc"}), (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socAlbLogS3);

// =====================================================
// Scenario 2: Internet -> ALB -> Pod -> RDS
// =====================================================

MATCH (internet:Internet {id: "internet"}), (prodAlb:ALB {id: "hap-public-web-alb"})
MERGE (internet)-[:EXPOSED_TO_INTERNET {
  description: "Prod ALB is reachable from the Internet"
}]->(prodAlb);

MATCH (prodAlb:ALB {id: "hap-public-web-alb"}), (pod:Pod {id: "pod-gitea-app"})
MERGE (prodAlb)-[:ALLOWS_TRAFFIC {
  protocol: "HTTPS",
  description: "ALB forwards traffic to Gitea Pod"
}]->(pod);

MATCH (prodAlb:ALB {id: "hap-public-web-alb"}), (pod:Pod {id: "pod-gitea-app"})
MERGE (prodAlb)-[:CAN_MOVE_TO {
  description: "Compromised public entry point can reach Gitea workload"
}]->(pod);

MATCH (pod:Pod {id: "pod-gitea-app"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (pod)-[:CONNECTS_TO {
  protocol: "PostgreSQL",
  port: 5432,
  description: "Gitea Pod connects to RDS"
}]->(rds);

// =====================================================
// Scenario 4: Pod -> ServiceAccount -> IRSA -> Secret -> RDS
// =====================================================

MATCH (pod:Pod {id: "pod-gitea-app"}), (eks:EKSCluster {id: "hap-eks-cluster"})
MERGE (pod)-[:RUNS_ON]->(eks);

MATCH (pod:Pod {id: "pod-gitea-app"}), (sa:ServiceAccount {id: "gitea-sa"})
MERGE (pod)-[:USES_SERVICE_ACCOUNT]->(sa);

MATCH (sa:ServiceAccount {id: "gitea-sa"}), (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
MERGE (sa)-[:IRSA_LINKED_TO]->(irsaRole);

MATCH (irsaRole:IAMRole {id: "hap-irsa-gitea-role"}), (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
MERGE (irsaRole)-[:HAS_PERMISSION]->(giteaRolePolicy);

MATCH (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"}), (secret:SecretsManager {id: "hap-gitea-db-secret"})
MERGE (giteaRolePolicy)-[:CAN_ACCESS {
  action: "secretsmanager:GetSecretValue",
  description: "IRSA policy can read Gitea DB secret"
}]->(secret);

MATCH (secret:SecretsManager {id: "hap-gitea-db-secret"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (secret)-[:CONNECTS_TO {
  description: "Secret contains RDS credential"
}]->(rds);

MATCH (secret:SecretsManager {id: "hap-gitea-db-secret"}), (kms:KMSKey {id: "hap-kms-key"})
MERGE (secret)-[:ENCRYPTED_BY]->(kms);

// =====================================================
// S1-A / Scenario 3: On-Prem Web Key
// =====================================================

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (webKey:Credential {id: "hap-onprem-web-key"})
MERGE (onpremWeb)-[:HAS_CREDENTIAL {
  credentialType: "IAM_ACCESS_KEY"
}]->(webKey);

MATCH (webKey:Credential {id: "hap-onprem-web-key"}), (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
MERGE (webKey)-[:HAS_PERMISSION {
  description: "Web Credential uses prefix-restricted S3 policy"
}]->(webPolicy);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "wordpress-files/",
  permissionLevel: "WRITE",
  description: "Web backup files prefix"
}]->(customerS3);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "wordpress-db/",
  permissionLevel: "WRITE",
  description: "WordPress database backup prefix"
}]->(customerS3);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "onprem/",
  permissionLevel: "WRITE",
  description: "On-Prem Web log prefix"
}]->(socLogS3);

// =====================================================
// DB Log-Only Credential
// =====================================================

MATCH (onpremDb:OnPremDB {id: "hap-onprem-db"}), (dbKey:Credential {id: "hap-onprem-db-key"})
MERGE (onpremDb)-[:HAS_CREDENTIAL {
  credentialType: "IAM_ACCESS_KEY"
}]->(dbKey);

MATCH (dbKey:Credential {id: "hap-onprem-db-key"}), (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-log-policy"})
MERGE (dbKey)-[:HAS_PERMISSION {
  description: "DB Credential uses log-only policy"
}]->(dbLogPolicy);

MATCH (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-log-policy"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (dbLogPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "onprem/",
  permissionLevel: "WRITE",
  description: "On-Prem DB log prefix"
}]->(socLogS3);

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (onpremDb:OnPremDB {id: "hap-onprem-db"})
MERGE (onpremWeb)-[:CONNECTS_TO {
  protocol: "MySQL",
  port: 3306
}]->(onpremDb);

// =====================================================
// S1-B: IAM User Key -> User -> Role -> Policy -> S3
// =====================================================

MATCH (devUser:IAMUser {id: "hap-dev-01-user"}), (devAccessKey:Credential {id: "hap-dev-01-access-key"})
MERGE (devUser)-[:HAS_CREDENTIAL {
  credentialType: "IAM_ACCESS_KEY"
}]->(devAccessKey);

MATCH (devAccessKey:Credential {id: "hap-dev-01-access-key"}), (devUser:IAMUser {id: "hap-dev-01-user"})
MERGE (devAccessKey)-[:AUTHENTICATES_AS {
  description: "Compromised IAM User key authenticates as hap-dev-01-user"
}]->(devUser);

MATCH (devUser:IAMUser {id: "hap-dev-01-user"}), (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
MERGE (devUser)-[:ASSUMES_ROLE {
  action: "sts:AssumeRole"
}]->(s3ReadonlyRole);

MATCH (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"}), (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"})
MERGE (s3ReadonlyRole)-[:HAS_PERMISSION]->(s3ReadonlyPolicy);

MATCH (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (s3ReadonlyPolicy)-[:CAN_ACCESS {
  action: "s3:ListBucket,s3:GetObject",
  resourcePrefix: "*",
  permissionLevel: "READ",
  description: "Readonly access to customer data bucket"
}]->(customerS3);

// =====================================================
// Logging / Encryption / Runtime Relationships
// =====================================================

MATCH (prodAlb:ALB {id: "hap-public-web-alb"}), (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (prodAlb)-[:LOGS_TO {
  logType: "ALB_ACCESS_LOG",
  prefix: "prod-alb/",
  encryption: "SSE-S3"
}]->(socAlbLogS3);

MATCH (socLogS3:S3Bucket {id: "hap-soc-log-s3"}), (kms:KMSKey {id: "hap-kms-key"})
MERGE (socLogS3)-[:ENCRYPTED_BY {
  encryption: "SSE-KMS"
}]->(kms);

MATCH (pod:Pod {id: "pod-gitea-app"}), (ecr:ECRRepository {id: "hap-gitea-ecr"})
MERGE (pod)-[:PULLS_IMAGE_FROM]->(ecr);

MATCH (pod:Pod {id: "pod-gitea-app"}), (cw:CloudWatchLog {id: "hap-gitea-cloudwatch-log"})
MERGE (pod)-[:LOGS_TO {
  logType: "APPLICATION_LOG"
}]->(cw);

// =====================================================
// Findings
// =====================================================

MATCH (prodAlb:ALB {id: "hap-public-web-alb"}), (findingAlb:Finding {id: "finding-alb-public-exposure"})
MERGE (prodAlb)-[:HAS_FINDING]->(findingAlb);

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (findingWebKey:Finding {id: "finding-onprem-web-key-exposure"})
MERGE (onpremWeb)-[:HAS_FINDING]->(findingWebKey);

MATCH (devAccessKey:Credential {id: "hap-dev-01-access-key"}), (findingDevKey:Finding {id: "finding-dev-access-key-exposure"})
MERGE (devAccessKey)-[:HAS_FINDING]->(findingDevKey);
