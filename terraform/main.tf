module "vpc" {
  source = "./modules/vpc"

  azs            = var.azs
  prod_nat_count = var.prod_nat_count
}

module "sg" {
  source = "./modules/sg"

  prod_vpc_id     = module.vpc.prod_vpc_id
  soc_vpc_id      = module.vpc.soc_vpc_id
  analyst_ip_cidr = var.analyst_ip_cidr
}

module "kms" {
  source = "./modules/kms"
}

module "secrets" {
  source = "./modules/secrets"

  prod_secrets_cmk_arn = module.kms.prod_secrets_cmk_arn
  soc_secrets_cmk_arn  = module.kms.soc_secrets_cmk_arn
}

module "rds" {
  source = "./modules/rds"

  prod_db_subnet_ids = module.vpc.prod_db_subnet_ids
  soc_db_subnet_ids  = module.vpc.soc_db_subnet_ids
  prod_db_sg_id      = module.sg.prod_db_sg_id
  soc_db_sg_id       = module.sg.soc_db_sg_id
  prod_rds_cmk_arn   = module.kms.prod_rds_cmk_arn
  soc_rds_cmk_arn    = module.kms.soc_rds_cmk_arn
  gitea_db_password  = module.secrets.gitea_db_password
  soc_db_password    = module.secrets.soc_db_password
}

module "s3" {
  source = "./modules/s3"

  data_cmk_arn = module.kms.data_cmk_arn
  log_cmk_arn  = module.kms.log_cmk_arn
}

module "eks" {
  source = "./modules/eks"

  prod_app_subnet_ids = module.vpc.prod_app_subnet_ids
  prod_app_sg_id      = module.sg.prod_app_sg_id
  eks_stage           = var.eks_stage
}

module "ec2_soc" {
  source = "./modules/ec2_soc"

  soc_app_subnet_ids  = module.vpc.soc_app_subnet_ids
  soc_collector_sg_id = module.sg.soc_collector_sg_id
  soc_server_sg_id    = module.sg.soc_server_sg_id
  soc_secrets_cmk_arn = module.kms.soc_secrets_cmk_arn
  soc_db_secret_arn   = module.secrets.soc_db_secret_arn
  jwt_secret_arn      = module.secrets.jwt_secret_arn
  neo4j_secret_arn    = module.secrets.neo4j_secret_arn
}

module "alb" {
  source = "./modules/alb"

  prod_vpc_id            = module.vpc.prod_vpc_id
  soc_vpc_id             = module.vpc.soc_vpc_id
  prod_public_subnet_ids = module.vpc.prod_public_subnet_ids
  soc_public_subnet_ids  = module.vpc.soc_public_subnet_ids
  prod_alb_sg_id         = module.sg.prod_alb_sg_id
  soc_alb_sg_id          = module.sg.soc_alb_sg_id
  soc_api_instance_id    = module.ec2_soc.api_instance_id
  acm_arn                = var.acm_arn
  alb_log_bucket_id      = module.s3.alb_log_bucket_id
}

module "ecr" {
  source = "./modules/ecr"
}

module "logging" {
  source = "./modules/logging"

  log_bucket_id            = module.s3.log_bucket_id
  log_bucket_arn           = module.s3.log_bucket_arn
  log_cmk_arn              = module.kms.log_cmk_arn
  customer_data_bucket_arn = module.s3.customer_data_bucket_arn
  prod_vpc_id              = module.vpc.prod_vpc_id
  soc_vpc_id               = module.vpc.soc_vpc_id
}

module "iam" {
  source = "./modules/iam"

  iam_mode                 = var.iam_mode
  customer_data_bucket_arn = module.s3.customer_data_bucket_arn
  irsa_gitea_role_name     = module.eks.irsa_gitea_role_name
  gitea_db_secret_arn      = module.secrets.gitea_db_secret_arn
  prod_secrets_cmk_arn     = module.kms.prod_secrets_cmk_arn
  log_bucket_arn           = module.s3.log_bucket_arn
  data_cmk_arn             = module.kms.data_cmk_arn
  log_cmk_arn              = module.kms.log_cmk_arn
}
