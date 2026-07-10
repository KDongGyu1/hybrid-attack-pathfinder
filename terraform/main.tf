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
