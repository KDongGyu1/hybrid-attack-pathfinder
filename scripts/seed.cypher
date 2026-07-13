// =====================================================
// Hybrid Attack Path Backend1
// Neo4j Seed Data
// Infra Spec v2 aligned
//
// 반영 사항
// 1. Redis 제거
// 2. hap-* 확정 리소스명으로 통일
// 3. On-Prem → IAM Access Key → AWS S3 경로
// 4. ALB Access Log 전용 S3 버킷 분리
// =====================================================


// =====================================================
// Reset Graph
// =====================================================

MATCH (n)
DETACH DELETE n;


// =====================================================
// Network / Infra Nodes
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

MERGE (alb:ALB {id: "hap-public-web-alb"})
SET alb.name = "hap-public-web-alb",
    alb.displayName = "Public Web ALB",
    alb.type = "ALB",
    alb.environment = "prod",
    alb.exposed = true,
    alb.provider = "AWS";

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
// AWS IAM Nodes
// =====================================================

MERGE (devUser:IAMUser {id: "hap-dev-01-user"})
SET devUser.name = "hap-dev-01-user",
    devUser.displayName = "hap-dev-01-user",
    devUser.type = "IAMUser",
    devUser.provider = "AWS";

MERGE (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"})
SET s3AccessPolicy.name = "hap-s3-access-policy",
    s3AccessPolicy.displayName = "hap-s3-access-policy",
    s3AccessPolicy.type = "IAMPolicy",
    s3AccessPolicy.provider = "AWS",
    s3AccessPolicy.permission = "s3:GetObject",
    s3AccessPolicy.scope = "S1-direct-access";

MERGE (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
SET s3ReadonlyRole.name = "hap-s3-readonly-role",
    s3ReadonlyRole.displayName = "hap-s3-readonly-role",
    s3ReadonlyRole.type = "IAMRole",
    s3ReadonlyRole.provider = "AWS",
    s3ReadonlyRole.note =
      "S1 path B assume role. Permission policy node pending confirmation.";

MERGE (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
SET irsaRole.name = "hap-irsa-gitea-role",
    irsaRole.displayName = "hap-irsa-gitea-role",
    irsaRole.type = "IAMRole",
    irsaRole.provider = "AWS",
    irsaRole.scope = "S4-IRSA";

MERGE (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
SET giteaRolePolicy.name = "hap-gitea-role-policy",
    giteaRolePolicy.displayName = "hap-gitea-role-policy",
    giteaRolePolicy.type = "IAMPolicy",
    giteaRolePolicy.provider = "AWS",
    giteaRolePolicy.scope = "S4-IRSA-policy";

MERGE (onpremAccessKey:IAMAccessKey {id: "hap-onprem-access-key"})
SET onpremAccessKey.name = "hap-onprem-access-key",
    onpremAccessKey.displayName = "Compromised IAM Access Key",
    onpremAccessKey.type = "IAMAccessKey",
    onpremAccessKey.provider = "AWS",
    onpremAccessKey.compromised = true;


// =====================================================
// AWS Data / Application Service Nodes
// =====================================================

MERGE (customerS3:S3Bucket {id: "hap-customer-data-s3"})
SET customerS3.name = "hap-customer-data-s3",
    customerS3.displayName = "hap-customer-data-s3",
    customerS3.type = "S3Bucket",
    customerS3.provider = "AWS",
    customerS3.environment = "prod",
    customerS3.purpose = "customer-data",
    customerS3.sensitive = true,
    customerS3.dataType = "customer-data";

MERGE (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
SET socLogS3.name = "hap-soc-log-s3",
    socLogS3.displayName = "SOC Audit and Collection Log Bucket",
    socLogS3.type = "S3Bucket",
    socLogS3.provider = "AWS",
    socLogS3.environment = "soc",
    socLogS3.purpose = "audit-and-collection-logs",
    socLogS3.encryption = "SSE-KMS",
    socLogS3.objectLock = true,
    socLogS3.sensitive = true;

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
    rds.displayName = "hap-gitea-db",
    rds.type = "RDS",
    rds.engine = "PostgreSQL",
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
// On-Prem Nodes
// =====================================================

MERGE (onpremWeb:OnPremWeb {id: "hap-onprem-web"})
SET onpremWeb.name = "hap-onprem-web",
    onpremWeb.displayName = "On-Prem WordPress Server",
    onpremWeb.type = "OnPremWeb",
    onpremWeb.environment = "on-prem",
    onpremWeb.application = "WordPress",
    onpremWeb.compromised = true;

MERGE (onpremDb:OnPremDB {id: "hap-onprem-db"})
SET onpremDb.name = "hap-onprem-db",
    onpremDb.displayName = "On-Prem MySQL Database",
    onpremDb.type = "OnPremDB",
    onpremDb.environment = "on-prem",
    onpremDb.engine = "MySQL";


// =====================================================
// Finding Nodes
// =====================================================

MERGE (findingAlbPublic:Finding {id: "finding-alb-public-exposure"})
SET findingAlbPublic.name = "finding-alb-public-exposure",
    findingAlbPublic.displayName = "ALB is exposed to the Internet",
    findingAlbPublic.type = "Finding",
    findingAlbPublic.severity = "MEDIUM";

MERGE (findingOnpremKey:Finding {id: "finding-onprem-access-key-exposure"})
SET findingOnpremKey.name = "finding-onprem-access-key-exposure",
    findingOnpremKey.displayName =
      "IAM Access Key stored on On-Prem WordPress server",
    findingOnpremKey.type = "Finding",
    findingOnpremKey.severity = "HIGH";

MERGE (findingS3Permission:Finding {id: "finding-s3-excessive-permission"})
SET findingS3Permission.name = "finding-s3-excessive-permission",
    findingS3Permission.displayName = "Excessive S3 access permission",
    findingS3Permission.type = "Finding",
    findingS3Permission.severity = "HIGH";


// =====================================================
// Containment Relationships
// =====================================================

MATCH
  (prodVpc:VPC {id: "hap-prod-vpc"}),
  (publicSubnet:Subnet {id: "hap-prod-public-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(publicSubnet);

MATCH
  (prodVpc:VPC {id: "hap-prod-vpc"}),
  (appSubnet:Subnet {id: "hap-prod-app-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(appSubnet);

MATCH
  (prodVpc:VPC {id: "hap-prod-vpc"}),
  (dbSubnet:Subnet {id: "hap-prod-db-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(dbSubnet);

MATCH
  (publicSubnet:Subnet {id: "hap-prod-public-subnet"}),
  (alb:ALB {id: "hap-public-web-alb"})
MERGE (publicSubnet)-[:CONTAINS]->(alb);

MATCH
  (appSubnet:Subnet {id: "hap-prod-app-subnet"}),
  (eks:EKSCluster {id: "hap-eks-cluster"})
MERGE (appSubnet)-[:CONTAINS]->(eks);

MATCH
  (dbSubnet:Subnet {id: "hap-prod-db-subnet"}),
  (rds:RDS {id: "hap-gitea-db"})
MERGE (dbSubnet)-[:CONTAINS]->(rds);

MATCH
  (socVpc:VPC {id: "hap-soc-vpc"}),
  (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socLogS3);

MATCH
  (socVpc:VPC {id: "hap-soc-vpc"}),
  (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socAlbLogS3);


// =====================================================
// Internet → ALB → Pod Path
// =====================================================

MATCH
  (internet:Internet {id: "internet"}),
  (alb:ALB {id: "hap-public-web-alb"})
MERGE (internet)-[:EXPOSED_TO_INTERNET {
  description: "Public Web ALB is reachable from the Internet"
}]->(alb);

MATCH
  (alb:ALB {id: "hap-public-web-alb"}),
  (pod:Pod {id: "pod-gitea-app"})
MERGE (alb)-[:ALLOWS_TRAFFIC {
  protocol: "HTTP/HTTPS",
  description: "ALB forwards web traffic to Gitea application pod"
}]->(pod);

MATCH
  (alb:ALB {id: "hap-public-web-alb"}),
  (pod:Pod {id: "pod-gitea-app"})
MERGE (alb)-[:CAN_MOVE_TO {
  description:
    "Attacker can move from public entry point to application workload"
}]->(pod);


// =====================================================
// ALB Access Log Bucket Separation
// Prod ALB → hap-soc-alb-log-s3 / prod-alb/
// SOC ALB 관계는 실제 SOC ALB id 확정 후 추가
// =====================================================

MATCH
  (alb:ALB {id: "hap-public-web-alb"}),
  (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (alb)-[:LOGS_TO {
  logType: "ALB_ACCESS_LOG",
  prefix: "prod-alb/",
  encryption: "SSE-S3",
  description:
    "Prod ALB access logs are stored in the dedicated ALB log bucket"
}]->(socAlbLogS3);


// =====================================================
// Audit Log Bucket Encryption
// hap-soc-log-s3만 KMS 연결
// hap-soc-alb-log-s3는 SSE-S3이므로 KMS 연결 금지
// =====================================================

MATCH
  (socLogS3:S3Bucket {id: "hap-soc-log-s3"}),
  (kms:KMSKey {id: "hap-kms-key"})
MERGE (socLogS3)-[:ENCRYPTED_BY {
  encryption: "SSE-KMS",
  description:
    "Audit and collection log bucket is encrypted with KMS"
}]->(kms);


// =====================================================
// EKS / IRSA / S3 Path
// =====================================================

MATCH
  (pod:Pod {id: "pod-gitea-app"}),
  (eks:EKSCluster {id: "hap-eks-cluster"})
MERGE (pod)-[:RUNS_ON {
  description: "Gitea application pod runs on EKS cluster"
}]->(eks);

MATCH
  (pod:Pod {id: "pod-gitea-app"}),
  (sa:ServiceAccount {id: "gitea-sa"})
MERGE (pod)-[:USES_SERVICE_ACCOUNT {
  description: "Gitea pod uses Kubernetes ServiceAccount"
}]->(sa);

MATCH
  (sa:ServiceAccount {id: "gitea-sa"}),
  (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
MERGE (sa)-[:IRSA_LINKED_TO {
  description: "ServiceAccount is linked to IAM Role through IRSA"
}]->(irsaRole);

MATCH
  (irsaRole:IAMRole {id: "hap-irsa-gitea-role"}),
  (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
MERGE (irsaRole)-[:HAS_PERMISSION {
  description: "IRSA Role has IAM Policy"
}]->(giteaRolePolicy);

MATCH
  (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"}),
  (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (giteaRolePolicy)-[:CAN_ACCESS {
  action: "s3:GetObject",
  permissionLevel: "READ",
  description: "IRSA policy allows access to customer data S3 bucket"
}]->(customerS3);


// =====================================================
// Pod → RDS Path
// =====================================================

MATCH
  (pod:Pod {id: "pod-gitea-app"}),
  (rds:RDS {id: "hap-gitea-db"})
MERGE (pod)-[:CONNECTS_TO {
  protocol: "PostgreSQL",
  port: 5432,
  description: "Gitea pod connects to RDS PostgreSQL"
}]->(rds);


// =====================================================
// Pod → Secrets Manager → RDS Path
// =====================================================

MATCH
  (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"}),
  (secret:SecretsManager {id: "hap-gitea-db-secret"})
MERGE (giteaRolePolicy)-[:CAN_ACCESS_SECRET {
  action: "secretsmanager:GetSecretValue",
  description: "Policy allows reading DB credential from Secrets Manager"
}]->(secret);

MATCH
  (secret:SecretsManager {id: "hap-gitea-db-secret"}),
  (rds:RDS {id: "hap-gitea-db"})
MERGE (secret)-[:CONNECTS_TO {
  description: "Secret contains credential for RDS PostgreSQL"
}]->(rds);

MATCH
  (secret:SecretsManager {id: "hap-gitea-db-secret"}),
  (kms:KMSKey {id: "hap-kms-key"})
MERGE (secret)-[:ENCRYPTED_BY {
  description: "Secret is encrypted by KMS key"
}]->(kms);


// =====================================================
// ECR / CloudWatch Relationships
// =====================================================

MATCH
  (pod:Pod {id: "pod-gitea-app"}),
  (ecr:ECRRepository {id: "hap-gitea-ecr"})
MERGE (pod)-[:PULLS_IMAGE_FROM {
  description: "Gitea pod pulls container image from ECR"
}]->(ecr);

MATCH
  (pod:Pod {id: "pod-gitea-app"}),
  (cw:CloudWatchLog {id: "hap-gitea-cloudwatch-log"})
MERGE (pod)-[:LOGS_TO {
  logType: "APPLICATION_LOG",
  description: "Gitea pod sends application logs to CloudWatch"
}]->(cw);


// =====================================================
// On-Prem → AWS Hybrid Attack Path
// =====================================================

MATCH
  (onpremWeb:OnPremWeb {id: "hap-onprem-web"}),
  (onpremDb:OnPremDB {id: "hap-onprem-db"})
MERGE (onpremWeb)-[:CONNECTS_TO {
  protocol: "MySQL",
  port: 3306,
  description: "WordPress server connects to on-prem MySQL database"
}]->(onpremDb);

MATCH
  (onpremWeb:OnPremWeb {id: "hap-onprem-web"}),
  (onpremAccessKey:IAMAccessKey {id: "hap-onprem-access-key"})
MERGE (onpremWeb)-[:HAS_ACCESS_KEY {
  description:
    "Compromised WordPress server contains AWS IAM Access Key"
}]->(onpremAccessKey);

MATCH
  (onpremAccessKey:IAMAccessKey {id: "hap-onprem-access-key"}),
  (devUser:IAMUser {id: "hap-dev-01-user"})
MERGE (onpremAccessKey)-[:AUTHENTICATES_AS {
  description: "Stolen IAM Access Key authenticates as IAM User"
}]->(devUser);

MATCH
  (devUser:IAMUser {id: "hap-dev-01-user"}),
  (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"})
MERGE (devUser)-[:HAS_PERMISSION {
  description: "IAM User has S3 access policy"
}]->(s3AccessPolicy);

MATCH
  (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"}),
  (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (s3AccessPolicy)-[:CAN_ACCESS {
  action: "s3:GetObject",
  permissionLevel: "READ",
  description: "Policy allows read access to customer data S3 bucket"
}]->(customerS3);


// =====================================================
// S1 Path B Placeholder
// =====================================================

MATCH
  (devUser:IAMUser {id: "hap-dev-01-user"}),
  (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
MERGE (devUser)-[:ASSUMES_ROLE {
  description:
    "IAM User can assume S3 readonly role. Policy pending confirmation."
}]->(s3ReadonlyRole);


// =====================================================
// Finding Relationships
// =====================================================

MATCH
  (alb:ALB {id: "hap-public-web-alb"}),
  (finding:Finding {id: "finding-alb-public-exposure"})
MERGE (alb)-[:HAS_FINDING]->(finding);

MATCH
  (onpremWeb:OnPremWeb {id: "hap-onprem-web"}),
  (finding:Finding {id: "finding-onprem-access-key-exposure"})
MERGE (onpremWeb)-[:HAS_FINDING]->(finding);

MATCH
  (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"}),
  (finding:Finding {id: "finding-s3-excessive-permission"})
MERGE (s3AccessPolicy)-[:HAS_FINDING]->(finding);


// =====================================================
// Seed Complete
// =====================================================