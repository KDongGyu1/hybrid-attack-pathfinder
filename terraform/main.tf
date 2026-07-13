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
