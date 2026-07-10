MATCH (n)
DETACH DELETE n;

CREATE
(internet:Internet {
  id: "internet",
  name: "Internet",
  type: "Internet"
}),
(vpc:VPC {
  id: "vpc-prod",
  name: "Prod VPC",
  cidr: "10.0.0.0/16",
  cloudProvider: "AWS"
}),
(publicSubnet:Subnet {
  id: "subnet-public-2a",
  name: "Public Subnet 2a",
  cidr: "10.0.1.0/24",
  subnetType: "public",
  az: "ap-northeast-2a"
}),
(appSubnet:Subnet {
  id: "subnet-private-app-2a",
  name: "Private App Subnet 2a",
  cidr: "10.0.11.0/24",
  subnetType: "private",
  az: "ap-northeast-2a"
}),
(dbSubnet:Subnet {
  id: "subnet-private-db-2a",
  name: "Private DB Subnet 2a",
  cidr: "10.0.21.0/24",
  subnetType: "private",
  az: "ap-northeast-2a"
}),
(alb:ALB {
  id: "alb-public-web",
  name: "Public Web ALB",
  scheme: "internet-facing",
  publicExposure: true
}),
(eks:EKSCluster {
  id: "eks-prod-main",
  name: "prod-main-eks",
  version: "1.29",
  endpointPublicAccess: false
}),
(pod:Pod {
  id: "pod-gitea-app",
  name: "gitea-app-pod",
  namespace: "prod",
  appName: "gitea"
}),
(sa:ServiceAccount {
  id: "sa-gitea-app",
  name: "gitea-app-sa",
  namespace: "prod"
}),
(role:IAMRole {
  id: "role-gitea-app",
  name: "GiteaAppRole",
  arn: "arn:aws:iam::123456789012:role/GiteaAppRole"
}),
(policy:IAMPolicy {
  id: "policy-s3-read-customer",
  name: "S3ReadCustomerDataPolicy",
  riskLevel: "high"
}),
(s3:S3Bucket {
  id: "s3-customer-data",
  name: "hap-customer-data-s3",
  containsSensitiveData: true,
  publicAccess: false
}),
(secret:SecretsManager {
  id: "secret-rds-credential",
  name: "prod/rds/postgres/credential",
  secretType: "database-credential"
}),
(rds:RDS {
  id: "rds-postgres-prod",
  name: "prod-postgres",
  engine: "postgresql",
  containsSensitiveData: true
}),
(redis:Redis {
  id: "redis-prod-cache",
  name: "prod-redis-cache",
  engine: "redis",
  authEnabled: true
}),
(kms:KMSKey {
  id: "kms-prod-main",
  name: "prod-main-kms-key",
  rotationEnabled: true
}),
(ecr:ECRRepository {
  id: "ecr-gitea-app",
  name: "gitea-app-repository",
  imageCount: 12
}),
(log:CloudWatchLog {
  id: "cw-prod-app-log",
  name: "prod-app-cloudwatch-log",
  retentionDays: 30
}),
(findingAlb:Finding {
  id: "finding-public-alb",
  title: "Public ALB exposed to Internet",
  severity: "medium",
  description: "The public ALB is reachable from the Internet."
}),
(findingIam:Finding {
  id: "finding-over-permissive-s3-policy",
  title: "Over-permissive S3 read permission",
  severity: "high",
  description: "The IAM policy allows reading sensitive customer data bucket."
}),
(findingRds:Finding {
  id: "finding-rds-reachable",
  title: "RDS reachable from application workload",
  severity: "high",
  description: "The RDS instance is reachable from the compromised application path."
});

MATCH
(internet:Internet {id: "internet"}),
(vpc:VPC {id: "vpc-prod"}),
(publicSubnet:Subnet {id: "subnet-public-2a"}),
(appSubnet:Subnet {id: "subnet-private-app-2a"}),
(dbSubnet:Subnet {id: "subnet-private-db-2a"}),
(alb:ALB {id: "alb-public-web"}),
(eks:EKSCluster {id: "eks-prod-main"}),
(pod:Pod {id: "pod-gitea-app"}),
(sa:ServiceAccount {id: "sa-gitea-app"}),
(role:IAMRole {id: "role-gitea-app"}),
(policy:IAMPolicy {id: "policy-s3-read-customer"}),
(s3:S3Bucket {id: "s3-customer-data"}),
(secret:SecretsManager {id: "secret-rds-credential"}),
(rds:RDS {id: "rds-postgres-prod"}),
(redis:Redis {id: "redis-prod-cache"}),
(kms:KMSKey {id: "kms-prod-main"}),
(ecr:ECRRepository {id: "ecr-gitea-app"}),
(log:CloudWatchLog {id: "cw-prod-app-log"}),
(findingAlb:Finding {id: "finding-public-alb"}),
(findingIam:Finding {id: "finding-over-permissive-s3-policy"}),
(findingRds:Finding {id: "finding-rds-reachable"})
CREATE
(vpc)-[:CONTAINS]->(publicSubnet),
(vpc)-[:CONTAINS]->(appSubnet),
(vpc)-[:CONTAINS]->(dbSubnet),
(publicSubnet)-[:CONTAINS]->(alb),
(appSubnet)-[:CONTAINS]->(eks),
(dbSubnet)-[:CONTAINS]->(rds),
(appSubnet)-[:CONTAINS]->(redis),
(pod)-[:RUNS_ON]->(eks),
(pod)-[:USES_SERVICE_ACCOUNT {riskWeight: 10}]->(sa),
(sa)-[:ASSUMES_ROLE {riskWeight: 25}]->(role),
(role)-[:HAS_POLICY {riskWeight: 10}]->(policy),
(pod)-[:PULLS_IMAGE_FROM]->(ecr),
(alb)-[:LOGS_TO]->(log),
(eks)-[:LOGS_TO]->(log),
(rds)-[:ENCRYPTED_BY]->(kms),
(secret)-[:ENCRYPTED_BY]->(kms),
(policy)-[:CAN_READ {
  action: "s3:GetObject",
  riskWeight: 30
}]->(s3),
(policy)-[:CAN_ACCESS_SECRET {
  action: "secretsmanager:GetSecretValue",
  riskWeight: 35
}]->(secret),
(secret)-[:CAN_MOVE_TO {
  reason: "DB credential stored in secret",
  riskWeight: 25
}]->(rds),
(internet)-[:EXPOSED_TO_INTERNET {
  port: 443,
  protocol: "HTTPS",
  riskWeight: 20
}]->(alb),
(alb)-[:CAN_MOVE_TO {
  reason: "Web application entry point",
  riskWeight: 20
}]->(pod),
(pod)-[:CAN_MOVE_TO {
  reason: "Compromised pod can access internal database network path",
  riskWeight: 15
}]->(rds),
(pod)-[:CAN_MOVE_TO {
  reason: "Compromised pod can attempt cache access",
  riskWeight: 10
}]->(redis),
(alb)-[:HAS_FINDING]->(findingAlb),
(policy)-[:HAS_FINDING]->(findingIam),
(rds)-[:HAS_FINDING]->(findingRds);