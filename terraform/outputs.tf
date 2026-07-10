output "prod_vpc_id" {
  value = module.vpc.prod_vpc_id
}

output "soc_vpc_id" {
  value = module.vpc.soc_vpc_id
}

output "prod_public_subnet_ids" {
  value = module.vpc.prod_public_subnet_ids
}

output "prod_app_subnet_ids" {
  value = module.vpc.prod_app_subnet_ids
}

output "prod_db_subnet_ids" {
  value = module.vpc.prod_db_subnet_ids
}

output "soc_public_subnet_ids" {
  value = module.vpc.soc_public_subnet_ids
}

output "soc_app_subnet_ids" {
  value = module.vpc.soc_app_subnet_ids
}

output "soc_db_subnet_ids" {
  value = module.vpc.soc_db_subnet_ids
}

output "peering_connection_id" {
  value = module.vpc.peering_connection_id
}
