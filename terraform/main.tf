module "vpc" {
  source = "./modules/vpc"

  azs            = var.azs
  prod_nat_count = var.prod_nat_count
}
