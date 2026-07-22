// Hybrid Attack Path Backend1
// Neo4j seed aligned with latest infra1 Terraform/K8s resource names.
// This file resets the local graph and recreates the runnable MVP model.

MATCH (n)
DETACH DELETE n;

// ---------------------------------------------------------------------------
// Core infrastructure
// ---------------------------------------------------------------------------

MERGE (internet:Internet {id: "internet"})
SET internet.name = "Internet",
    internet.displayName = "External attacker / Internet",
    internet.type = "Internet";

MERGE (prodVpc:VPC {id: "hap-prod-vpc"})
SET prodVpc.name = "hap-prod-vpc",
    prodVpc.displayName = "Prod VPC",
    prodVpc.environment = "prod",
    prodVpc.provider = "AWS";

MERGE (socVpc:VPC {id: "hap-soc-vpc"})
SET socVpc.name = "hap-soc-vpc",
    socVpc.displayName = "SOC VPC",
    socVpc.environment = "soc",
    socVpc.provider = "AWS";

MERGE (publicSubnet:Subnet {id: "hap-prod-public-subnet"})
SET publicSubnet.name = "hap-prod-public-subnet",
    publicSubnet.displayName = "Prod public subnet",
    publicSubnet.subnetType = "public",
    publicSubnet.provider = "AWS";

MERGE (appSubnet:Subnet {id: "hap-prod-app-subnet"})
SET appSubnet.name = "hap-prod-app-subnet",
    appSubnet.displayName = "Prod private app subnet",
    appSubnet.subnetType = "private-app",
    appSubnet.provider = "AWS";

MERGE (dbSubnet:Subnet {id: "hap-prod-db-subnet"})
SET dbSubnet.name = "hap-prod-db-subnet",
    dbSubnet.displayName = "Prod private DB subnet",
    dbSubnet.subnetType = "private-db",
    dbSubnet.provider = "AWS";

MERGE (prodAlb:ALB {id: "hap-prod-alb"})
SET prodAlb.name = "hap-prod-alb",
    prodAlb.displayName = "Prod ALB",
    prodAlb.environment = "prod",
    prodAlb.provider = "AWS",
    prodAlb.protocol = "HTTP",
    prodAlb.port = 80,
    prodAlb.exposed = true;

MERGE (eks:EKSCluster {id: "hap-eks"})
SET eks.name = "hap-eks",
    eks.displayName = "Prod EKS cluster",
    eks.provider = "AWS",
    eks.version = "1.33";

MERGE (pod:Pod {id: "pod-gitea-app"})
SET pod.name = "pod-gitea-app",
    pod.displayName = "Gitea application Pod",
    pod.namespace = "gitea",
    pod.workload = "gitea";

MERGE (sa:ServiceAccount {id: "gitea-sa"})
SET sa.name = "gitea-sa",
    sa.displayName = "gitea-sa",
    sa.namespace = "gitea";

MERGE (rds:RDS {id: "hap-gitea-db"})
SET rds.name = "hap-gitea-db",
    rds.displayName = "Gitea RDS PostgreSQL",
    rds.provider = "AWS",
    rds.engine = "PostgreSQL",
    rds.engineVersion = "16",
    rds.sensitive = true;

MERGE (customerS3:S3Bucket {id: "hap-customer-data-s3"})
SET customerS3.name = "hap-customer-data-s3",
    customerS3.displayName = "Customer data S3",
    customerS3.provider = "AWS",
    customerS3.environment = "prod",
    customerS3.encryption = "SSE-KMS",
    customerS3.kmsKeyId = "hap-data-cmk",
    customerS3.sensitive = true;

MERGE (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
SET socLogS3.name = "hap-soc-log-s3",
    socLogS3.displayName = "SOC audit and collection log bucket",
    socLogS3.provider = "AWS",
    socLogS3.environment = "soc",
    socLogS3.encryption = "SSE-KMS",
    socLogS3.kmsKeyId = "hap-log-cmk",
    socLogS3.objectLock = true;

MERGE (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
SET socAlbLogS3.name = "hap-soc-alb-log-s3",
    socAlbLogS3.displayName = "SOC ALB access log and AWS Config bucket",
    socAlbLogS3.provider = "AWS",
    socAlbLogS3.environment = "soc",
    socAlbLogS3.encryption = "SSE-S3",
    socAlbLogS3.objectLock = false,
    socAlbLogS3.prodPrefix = "prod-alb/",
    socAlbLogS3.socPrefix = "soc-alb/",
    socAlbLogS3.configPrefix = "config/";

MERGE (configPrefix:LogPrefix {id: "hap-soc-alb-log-s3/config"})
SET configPrefix.bucket = "hap-soc-alb-log-s3",
    configPrefix.prefix = "config/",
    configPrefix.logType = "AWS_CONFIG",
    configPrefix.encryption = "SSE-S3",
    configPrefix.objectLock = false;

// Confirmed KMS aliases from infra1 Terraform.
MERGE (dataKms:KMSKey {id: "hap-data-cmk"})
SET dataKms.name = "hap-data-cmk",
    dataKms.alias = "alias/hap-data-cmk",
    dataKms.provider = "AWS",
    dataKms.purpose = "customer-data-s3";

MERGE (logKms:KMSKey {id: "hap-log-cmk"})
SET logKms.name = "hap-log-cmk",
    logKms.alias = "alias/hap-log-cmk",
    logKms.provider = "AWS",
    logKms.purpose = "soc-log-s3";

MERGE (prodSecretsKms:KMSKey {id: "hap-prod-secrets-cmk"})
SET prodSecretsKms.name = "hap-prod-secrets-cmk",
    prodSecretsKms.alias = "alias/hap-prod-secrets-cmk",
    prodSecretsKms.provider = "AWS",
    prodSecretsKms.purpose = "prod-secrets";

MERGE (prodRdsKms:KMSKey {id: "hap-prod-rds-cmk"})
SET prodRdsKms.name = "hap-prod-rds-cmk",
    prodRdsKms.alias = "alias/hap-prod-rds-cmk",
    prodRdsKms.provider = "AWS",
    prodRdsKms.purpose = "prod-rds";

MERGE (secret:SecretsManager {id: "gitea-db-credentials"})
SET secret.name = "gitea-db-credentials",
    secret.displayName = "Gitea DB credentials mounted by CSI",
    secret.provider = "AWS/Kubernetes",
    secret.secretType = "db-credential",
    secret.k8sSecretName = "gitea-db-credentials",
    secret.awsSecretName = "hap-db-secret",
    secret.kmsKeyId = "hap-prod-secrets-cmk",
    secret.sensitive = true;

MERGE (ecr:ECRRepository {id: "hap-gitea-ecr"})
SET ecr.name = "hap-gitea-ecr",
    ecr.provider = "AWS";

MERGE (cw:CloudWatchLog {id: "hap-gitea-cloudwatch-log"})
SET cw.name = "hap-gitea-cloudwatch-log",
    cw.provider = "AWS";

// ---------------------------------------------------------------------------
// Identity, credential, and policy nodes
// ---------------------------------------------------------------------------

MERGE (devUser:IAMUser {id: "hap-dev-01-user"})
SET devUser.name = "hap-dev-01-user",
    devUser.provider = "AWS";

MERGE (devAccessKey:Credential:IAMAccessKey {id: "hap-dev-01-access-key"})
SET devAccessKey.name = "hap-dev-01-access-key",
    devAccessKey.provider = "AWS",
    devAccessKey.ownerIdentityId = "hap-dev-01-user",
    devAccessKey.compromised = true;

MERGE (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"})
SET s3AccessPolicy.name = "hap-s3-access-policy",
    s3AccessPolicy.provider = "AWS",
    s3AccessPolicy.scope = "S1-path-A",
    s3AccessPolicy.permission = "s3:*";

MERGE (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
SET s3ReadonlyRole.name = "hap-s3-readonly-role",
    s3ReadonlyRole.provider = "AWS";

MERGE (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"})
SET s3ReadonlyPolicy.name = "hap-s3-readonly-policy",
    s3ReadonlyPolicy.provider = "AWS",
    s3ReadonlyPolicy.scope = "S1-path-B",
    s3ReadonlyPolicy.permission = "s3:ListBucket,s3:GetObject";

MERGE (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
SET irsaRole.name = "hap-irsa-gitea-role",
    irsaRole.provider = "AWS";

MERGE (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
SET giteaRolePolicy.name = "hap-gitea-role-policy",
    giteaRolePolicy.provider = "AWS",
    giteaRolePolicy.permission = "secretsmanager:GetSecretValue,kms:Decrypt";

MERGE (onpremWeb:OnPremWeb {id: "hap-onprem-web"})
SET onpremWeb.name = "hap-onprem-web",
    onpremWeb.displayName = "On-Prem WordPress web server",
    onpremWeb.environment = "on-prem",
    onpremWeb.application = "WordPress";

MERGE (onpremWebUser:IAMUser {id: "hap-onprem-web-user"})
SET onpremWebUser.name = "hap-onprem-web-user",
    onpremWebUser.provider = "AWS",
    onpremWebUser.description = "Actual IAM user for the On-Prem web backup key";

MERGE (webKey:Credential:IAMAccessKey {id: "hap-onprem-web-key"})
SET webKey.name = "hap-onprem-web-key",
    webKey.provider = "AWS",
    webKey.ownerIdentityId = "hap-onprem-web-user",
    webKey.compromised = true;

MERGE (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
SET webPolicy.name = "hap-onprem-web-s3-policy",
    webPolicy.provider = "AWS",
    webPolicy.permission = "s3:PutObject,kms:GenerateDataKey",
    webPolicy.scope = "prefix-restricted";

MERGE (onpremDb:OnPremDB {id: "hap-onprem-db"})
SET onpremDb.name = "hap-onprem-db",
    onpremDb.displayName = "On-Prem MySQL database",
    onpremDb.environment = "on-prem",
    onpremDb.engine = "MySQL";

MERGE (onpremDbUser:IAMUser {id: "hap-onprem-db-user"})
SET onpremDbUser.name = "hap-onprem-db-user",
    onpremDbUser.provider = "AWS",
    onpremDbUser.description = "Actual IAM user for the On-Prem DB log key";

MERGE (dbKey:Credential:IAMAccessKey {id: "hap-onprem-db-key"})
SET dbKey.name = "hap-onprem-db-key",
    dbKey.provider = "AWS",
    dbKey.ownerIdentityId = "hap-onprem-db-user",
    dbKey.compromised = false;

MERGE (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-s3-policy"})
SET dbLogPolicy.name = "hap-onprem-db-s3-policy",
    dbLogPolicy.provider = "AWS",
    dbLogPolicy.permission = "s3:PutObject,kms:GenerateDataKey",
    dbLogPolicy.scope = "log-only";

// ---------------------------------------------------------------------------
// Containment and runtime relations
// ---------------------------------------------------------------------------

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (publicSubnet:Subnet {id: "hap-prod-public-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(publicSubnet);

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (appSubnet:Subnet {id: "hap-prod-app-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(appSubnet);

MATCH (prodVpc:VPC {id: "hap-prod-vpc"}), (dbSubnet:Subnet {id: "hap-prod-db-subnet"})
MERGE (prodVpc)-[:CONTAINS]->(dbSubnet);

MATCH (publicSubnet:Subnet {id: "hap-prod-public-subnet"}), (prodAlb:ALB {id: "hap-prod-alb"})
MERGE (publicSubnet)-[:CONTAINS]->(prodAlb);

MATCH (appSubnet:Subnet {id: "hap-prod-app-subnet"}), (eks:EKSCluster {id: "hap-eks"})
MERGE (appSubnet)-[:CONTAINS]->(eks);

MATCH (dbSubnet:Subnet {id: "hap-prod-db-subnet"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (dbSubnet)-[:CONTAINS]->(rds);

MATCH (socVpc:VPC {id: "hap-soc-vpc"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socLogS3);

MATCH (socVpc:VPC {id: "hap-soc-vpc"}), (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (socVpc)-[:CONTAINS]->(socAlbLogS3);

MATCH (internet:Internet {id: "internet"}), (prodAlb:ALB {id: "hap-prod-alb"})
MERGE (internet)-[:EXPOSED_TO_INTERNET {
  protocol: "HTTP",
  port: 80,
  description: "Prod ALB is reachable from the Internet on HTTP/80"
}]->(prodAlb);

MATCH (prodAlb:ALB {id: "hap-prod-alb"}), (pod:Pod {id: "pod-gitea-app"})
MERGE (prodAlb)-[:ALLOWS_TRAFFIC {
  protocol: "HTTP",
  port: 80,
  targetPort: 3000,
  description: "Prod ALB forwards HTTP traffic to the Gitea Pod"
}]->(pod);

MATCH (prodAlb:ALB {id: "hap-prod-alb"}), (pod:Pod {id: "pod-gitea-app"})
MERGE (prodAlb)-[:CAN_MOVE_TO {
  description: "Compromised public entry point can reach the Gitea workload"
}]->(pod);

MATCH (pod:Pod {id: "pod-gitea-app"}), (eks:EKSCluster {id: "hap-eks"})
MERGE (pod)-[:RUNS_ON]->(eks);

MATCH (pod:Pod {id: "pod-gitea-app"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (pod)-[:CONNECTS_TO {
  protocol: "PostgreSQL",
  port: 5432,
  description: "Gitea Pod connects to RDS"
}]->(rds);

MATCH (pod:Pod {id: "pod-gitea-app"}), (ecr:ECRRepository {id: "hap-gitea-ecr"})
MERGE (pod)-[:PULLS_IMAGE_FROM]->(ecr);

MATCH (pod:Pod {id: "pod-gitea-app"}), (cw:CloudWatchLog {id: "hap-gitea-cloudwatch-log"})
MERGE (pod)-[:LOGS_TO {logType: "APPLICATION_LOG"}]->(cw);

// ---------------------------------------------------------------------------
// S1 path A and B: dev-01 access key
// ---------------------------------------------------------------------------

MATCH (devUser:IAMUser {id: "hap-dev-01-user"}), (devAccessKey:Credential {id: "hap-dev-01-access-key"})
MERGE (devUser)-[:HAS_CREDENTIAL {credentialType: "IAM_ACCESS_KEY"}]->(devAccessKey);

MATCH (devAccessKey:Credential {id: "hap-dev-01-access-key"}), (devUser:IAMUser {id: "hap-dev-01-user"})
MERGE (devAccessKey)-[:AUTHENTICATES_AS {
  description: "Compromised dev-01 access key authenticates as hap-dev-01-user"
}]->(devUser);

MATCH (devUser:IAMUser {id: "hap-dev-01-user"}), (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"})
MERGE (devUser)-[:HAS_PERMISSION {
  description: "S1-A direct IAM policy"
}]->(s3AccessPolicy);

MATCH (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (s3AccessPolicy)-[:CAN_ACCESS {
  action: "s3:*",
  resourcePrefix: "*",
  permissionLevel: "FULL",
  description: "Direct customer data bucket access"
}]->(customerS3);

MATCH (s3AccessPolicy:IAMPolicy {id: "hap-s3-access-policy"}), (dataKms:KMSKey {id: "hap-data-cmk"})
MERGE (s3AccessPolicy)-[:CAN_ACCESS {
  action: "kms:Decrypt",
  permissionLevel: "DECRYPT",
  description: "Required for SSE-KMS customer data reads"
}]->(dataKms);

MATCH (devUser:IAMUser {id: "hap-dev-01-user"}), (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"})
MERGE (devUser)-[:ASSUMES_ROLE {action: "sts:AssumeRole"}]->(s3ReadonlyRole);

MATCH (s3ReadonlyRole:IAMRole {id: "hap-s3-readonly-role"}), (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"})
MERGE (s3ReadonlyRole)-[:HAS_PERMISSION]->(s3ReadonlyPolicy);

MATCH (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (s3ReadonlyPolicy)-[:CAN_ACCESS {
  action: "s3:ListBucket,s3:GetObject",
  resourcePrefix: "*",
  permissionLevel: "READ",
  description: "Readonly access to customer data bucket"
}]->(customerS3);

MATCH (s3ReadonlyPolicy:IAMPolicy {id: "hap-s3-readonly-policy"}), (dataKms:KMSKey {id: "hap-data-cmk"})
MERGE (s3ReadonlyPolicy)-[:CAN_ACCESS {
  action: "kms:Decrypt",
  permissionLevel: "DECRYPT",
  description: "Required for SSE-KMS customer data reads"
}]->(dataKms);

// ---------------------------------------------------------------------------
// S3: On-Prem WordPress and DB log-only structure
// ---------------------------------------------------------------------------

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (webKey:Credential {id: "hap-onprem-web-key"})
MERGE (onpremWeb)-[:HAS_CREDENTIAL {credentialType: "IAM_ACCESS_KEY"}]->(webKey);

MATCH (webKey:Credential {id: "hap-onprem-web-key"}), (onpremWebUser:IAMUser {id: "hap-onprem-web-user"})
MERGE (webKey)-[:AUTHENTICATES_AS {
  description: "On-Prem web key authenticates as its own IAM user, not dev-01"
}]->(onpremWebUser);

MATCH (onpremWebUser:IAMUser {id: "hap-onprem-web-user"}), (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
MERGE (onpremWebUser)-[:HAS_PERMISSION {
  description: "Prefix-restricted On-Prem web S3 policy"
}]->(webPolicy);

MATCH (webKey:Credential {id: "hap-onprem-web-key"}), (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"})
MERGE (webKey)-[:HAS_PERMISSION {
  description: "Credential-level shortcut for detection/path queries"
}]->(webPolicy);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "wordpress-files/",
  permissionLevel: "WRITE",
  description: "WordPress file backup upload prefix"
}]->(customerS3);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (customerS3:S3Bucket {id: "hap-customer-data-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "wordpress-db/",
  permissionLevel: "WRITE",
  description: "WordPress database backup upload prefix"
}]->(customerS3);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "onprem/",
  permissionLevel: "WRITE",
  description: "On-Prem web log upload prefix"
}]->(socLogS3);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (dataKms:KMSKey {id: "hap-data-cmk"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "kms:GenerateDataKey",
  permissionLevel: "ENCRYPT",
  description: "Required for SSE-KMS writes to customer data"
}]->(dataKms);

MATCH (webPolicy:IAMPolicy {id: "hap-onprem-web-s3-policy"}), (logKms:KMSKey {id: "hap-log-cmk"})
MERGE (webPolicy)-[:CAN_ACCESS {
  action: "kms:GenerateDataKey",
  permissionLevel: "ENCRYPT",
  description: "Required for SSE-KMS writes to SOC logs"
}]->(logKms);

MATCH (onpremDb:OnPremDB {id: "hap-onprem-db"}), (dbKey:Credential {id: "hap-onprem-db-key"})
MERGE (onpremDb)-[:HAS_CREDENTIAL {credentialType: "IAM_ACCESS_KEY"}]->(dbKey);

MATCH (dbKey:Credential {id: "hap-onprem-db-key"}), (onpremDbUser:IAMUser {id: "hap-onprem-db-user"})
MERGE (dbKey)-[:AUTHENTICATES_AS {
  description: "On-Prem DB key authenticates as its log-only IAM user"
}]->(onpremDbUser);

MATCH (onpremDbUser:IAMUser {id: "hap-onprem-db-user"}), (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-s3-policy"})
MERGE (onpremDbUser)-[:HAS_PERMISSION {
  description: "On-Prem DB log-only S3 policy"
}]->(dbLogPolicy);

MATCH (dbKey:Credential {id: "hap-onprem-db-key"}), (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-s3-policy"})
MERGE (dbKey)-[:HAS_PERMISSION {
  description: "Credential-level shortcut for log-only path queries"
}]->(dbLogPolicy);

MATCH (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-s3-policy"}), (socLogS3:S3Bucket {id: "hap-soc-log-s3"})
MERGE (dbLogPolicy)-[:CAN_ACCESS {
  action: "s3:PutObject",
  resourcePrefix: "onprem/",
  permissionLevel: "WRITE",
  description: "On-Prem DB log upload prefix"
}]->(socLogS3);

MATCH (dbLogPolicy:IAMPolicy {id: "hap-onprem-db-s3-policy"}), (logKms:KMSKey {id: "hap-log-cmk"})
MERGE (dbLogPolicy)-[:CAN_ACCESS {
  action: "kms:GenerateDataKey",
  permissionLevel: "ENCRYPT",
  description: "Required for SSE-KMS writes to SOC logs"
}]->(logKms);

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (onpremDb:OnPremDB {id: "hap-onprem-db"})
MERGE (onpremWeb)-[:CONNECTS_TO {protocol: "MySQL", port: 3306}]->(onpremDb);

// ---------------------------------------------------------------------------
// S4: Pod -> IRSA -> Secret -> RDS
// ---------------------------------------------------------------------------

MATCH (pod:Pod {id: "pod-gitea-app"}), (sa:ServiceAccount {id: "gitea-sa"})
MERGE (pod)-[:USES_SERVICE_ACCOUNT]->(sa);

MATCH (sa:ServiceAccount {id: "gitea-sa"}), (irsaRole:IAMRole {id: "hap-irsa-gitea-role"})
MERGE (sa)-[:IRSA_LINKED_TO {
  action: "sts:AssumeRoleWithWebIdentity"
}]->(irsaRole);

MATCH (irsaRole:IAMRole {id: "hap-irsa-gitea-role"}), (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"})
MERGE (irsaRole)-[:HAS_PERMISSION]->(giteaRolePolicy);

MATCH (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"}), (secret:SecretsManager {id: "gitea-db-credentials"})
MERGE (giteaRolePolicy)-[:CAN_ACCESS {
  action: "secretsmanager:GetSecretValue",
  description: "IRSA policy can read the Gitea DB secret"
}]->(secret);

MATCH (giteaRolePolicy:IAMPolicy {id: "hap-gitea-role-policy"}), (prodSecretsKms:KMSKey {id: "hap-prod-secrets-cmk"})
MERGE (giteaRolePolicy)-[:CAN_ACCESS {
  action: "kms:Decrypt",
  permissionLevel: "DECRYPT",
  description: "Required to decrypt the prod Gitea DB secret"
}]->(prodSecretsKms);

MATCH (secret:SecretsManager {id: "gitea-db-credentials"}), (rds:RDS {id: "hap-gitea-db"})
MERGE (secret)-[:CONNECTS_TO {
  description: "Secret contains RDS credentials consumed by the Gitea Pod"
}]->(rds);

MATCH (secret:SecretsManager {id: "gitea-db-credentials"}), (prodSecretsKms:KMSKey {id: "hap-prod-secrets-cmk"})
MERGE (secret)-[:ENCRYPTED_BY]->(prodSecretsKms);

MATCH (rds:RDS {id: "hap-gitea-db"}), (prodRdsKms:KMSKey {id: "hap-prod-rds-cmk"})
MERGE (rds)-[:ENCRYPTED_BY]->(prodRdsKms);

// ---------------------------------------------------------------------------
// Logging relations
// ---------------------------------------------------------------------------

MATCH (prodAlb:ALB {id: "hap-prod-alb"}), (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"})
MERGE (prodAlb)-[:LOGS_TO {
  logType: "ALB_ACCESS_LOG",
  protocol: "HTTP",
  port: 80,
  prefix: "prod-alb/",
  encryption: "SSE-S3"
}]->(socAlbLogS3);

MATCH (socAlbLogS3:S3Bucket {id: "hap-soc-alb-log-s3"}), (configPrefix:LogPrefix {id: "hap-soc-alb-log-s3/config"})
MERGE (socAlbLogS3)-[:HAS_LOG_PREFIX {
  prefix: "config/",
  logType: "AWS_CONFIG"
}]->(configPrefix);

MATCH (customerS3:S3Bucket {id: "hap-customer-data-s3"}), (dataKms:KMSKey {id: "hap-data-cmk"})
MERGE (customerS3)-[:ENCRYPTED_BY]->(dataKms);

MATCH (socLogS3:S3Bucket {id: "hap-soc-log-s3"}), (logKms:KMSKey {id: "hap-log-cmk"})
MERGE (socLogS3)-[:ENCRYPTED_BY]->(logKms);

// ---------------------------------------------------------------------------
// Scenario metadata and findings
// ---------------------------------------------------------------------------

MERGE (s1:Scenario {id: "S1"})
SET s1.name = "dev-01 IAM access key to customer S3",
    s1.status = "POTENTIAL",
    s1.severity = "HIGH";

MERGE (s2:Scenario {id: "S2"})
SET s2.name = "Internet to Gitea Pod and RDS",
    s2.status = "POTENTIAL",
    s2.severity = "HIGH";

MERGE (s3:Scenario {id: "S3"})
SET s3.name = "On-Prem WordPress key to S3 prefixes",
    s3.status = "POTENTIAL",
    s3.severity = "MEDIUM";

MERGE (s4:Scenario {id: "S4"})
SET s4.name = "Gitea Pod IRSA to Secret and RDS",
    s4.status = "POTENTIAL",
    s4.severity = "HIGH";

MERGE (statusReproduced:ScenarioStatus {id: "REPRODUCED"})
  SET statusReproduced.name = "REPRODUCED",
      statusReproduced.description = "Attack is reproduced and supported by logs";
MERGE (statusDetectable:ScenarioStatus {id: "DETECTABLE"})
  SET statusDetectable.name = "DETECTABLE",
      statusDetectable.description = "Detection rule exists but no matching event is currently present";
MERGE (statusDetected:ScenarioStatus {id: "DETECTED"})
  SET statusDetected.name = "DETECTED",
      statusDetected.description = "Current Event nodes match a detection rule";
MERGE (statusPotential:ScenarioStatus {id: "POTENTIAL"})
  SET statusPotential.name = "POTENTIAL",
      statusPotential.description = "Only asset, credential, permission, or network graph path exists";

MERGE (findingAlb:Finding {id: "finding-alb-public-http"})
SET findingAlb.name = "finding-alb-public-http",
    findingAlb.source = "SCOUT_SUITE",
    findingAlb.severity = "MEDIUM",
    findingAlb.cvss_score = 5.3,
    findingAlb.finding_type = "PUBLIC_HTTP",
    findingAlb.status = "OPEN",
    findingAlb.description = "Prod ALB is public on HTTP/80";

MERGE (findingDevKey:Finding {id: "finding-dev-access-key-exposure"})
SET findingDevKey.name = "finding-dev-access-key-exposure",
    findingDevKey.source = "SCOUT_SUITE",
    findingDevKey.severity = "HIGH",
    findingDevKey.cvss_score = 8.1,
    findingDevKey.finding_type = "EXPOSED_ACCESS_KEY",
    findingDevKey.status = "OPEN",
    findingDevKey.description = "dev-01 access key is compromised";

MERGE (findingWebKey:Finding {id: "finding-onprem-web-key-exposure"})
SET findingWebKey.name = "finding-onprem-web-key-exposure",
    findingWebKey.source = "SCOUT_SUITE",
    findingWebKey.severity = "HIGH",
    findingWebKey.cvss_score = 7.8,
    findingWebKey.finding_type = "EXPOSED_ACCESS_KEY",
    findingWebKey.status = "OPEN",
    findingWebKey.description = "On-Prem web access key is exposed";

MERGE (findingGiteaCritical:Finding {id: "finding-gitea-critical-cve"})
SET findingGiteaCritical.name = "finding-gitea-critical-cve",
    findingGiteaCritical.source = "TRIVY",
    findingGiteaCritical.severity = "CRITICAL",
    findingGiteaCritical.cvss_score = 9.8,
    findingGiteaCritical.cve_id = "CVE-2026-0001",
    findingGiteaCritical.finding_type = "CONTAINER_VULNERABILITY",
    findingGiteaCritical.status = "OPEN",
    findingGiteaCritical.description = "Critical Gitea container package finding";

MERGE (findingGiteaDuplicate:Finding {id: "finding-gitea-critical-cve-duplicate"})
SET findingGiteaDuplicate.name = "finding-gitea-critical-cve-duplicate",
    findingGiteaDuplicate.source = "TRIVY",
    findingGiteaDuplicate.severity = "CRITICAL",
    findingGiteaDuplicate.cvss_score = 9.8,
    findingGiteaDuplicate.cve_id = "CVE-2026-0001",
    findingGiteaDuplicate.finding_type = "CONTAINER_VULNERABILITY",
    findingGiteaDuplicate.status = "OPEN",
    findingGiteaDuplicate.description = "Duplicate record for the same CVE, retained to verify dedupe";

MERGE (findingSuppressed:Finding {id: "finding-suppressed-example"})
SET findingSuppressed.name = "finding-suppressed-example",
    findingSuppressed.source = "TRIVY",
    findingSuppressed.severity = "HIGH",
    findingSuppressed.cvss_score = 8.8,
    findingSuppressed.cve_id = "CVE-2026-9999",
    findingSuppressed.finding_type = "SUPPRESSED_TEST_FINDING",
    findingSuppressed.status = "SUPPRESSED",
    findingSuppressed.description = "Suppressed finding retained to verify exclusion";

MATCH (devAccessKey:Credential {id: "hap-dev-01-access-key"}), (findingDevKey:Finding {id: "finding-dev-access-key-exposure"})
MERGE (devAccessKey)-[:HAS_FINDING]->(findingDevKey);

MATCH (onpremWeb:OnPremWeb {id: "hap-onprem-web"}), (findingWebKey:Finding {id: "finding-onprem-web-key-exposure"})
MERGE (onpremWeb)-[:HAS_FINDING]->(findingWebKey);

MATCH (prodAlb:ALB {id: "hap-prod-alb"}), (findingAlb:Finding {id: "finding-alb-public-http"})
MERGE (prodAlb)-[:HAS_FINDING]->(findingAlb);

MATCH (pod:Pod {id: "pod-gitea-app"}), (findingGiteaCritical:Finding {id: "finding-gitea-critical-cve"})
MERGE (pod)-[:HAS_FINDING]->(findingGiteaCritical);

MATCH (pod:Pod {id: "pod-gitea-app"}), (findingGiteaDuplicate:Finding {id: "finding-gitea-critical-cve-duplicate"})
MERGE (pod)-[:HAS_FINDING]->(findingGiteaDuplicate);

MATCH (pod:Pod {id: "pod-gitea-app"}), (findingSuppressed:Finding {id: "finding-suppressed-example"})
MERGE (pod)-[:HAS_FINDING]->(findingSuppressed);
