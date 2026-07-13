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

output "prod_alb_sg_id" {
  value = module.sg.prod_alb_sg_id
}

output "prod_app_sg_id" {
  value = module.sg.prod_app_sg_id
}

output "prod_db_sg_id" {
  value = module.sg.prod_db_sg_id
}

output "soc_alb_sg_id" {
  value = module.sg.soc_alb_sg_id
}

output "soc_server_sg_id" {
  value = module.sg.soc_server_sg_id
}

output "soc_collector_sg_id" {
  value = module.sg.soc_collector_sg_id
}

output "soc_db_sg_id" {
  value = module.sg.soc_db_sg_id
}

output "prod_rds_cmk_arn" {
  value = module.kms.prod_rds_cmk_arn
}

output "soc_rds_cmk_arn" {
  value = module.kms.soc_rds_cmk_arn
}

output "prod_secrets_cmk_arn" {
  value = module.kms.prod_secrets_cmk_arn
}

output "soc_secrets_cmk_arn" {
  value = module.kms.soc_secrets_cmk_arn
}

output "data_cmk_arn" {
  value = module.kms.data_cmk_arn
}

output "log_cmk_arn" {
  value = module.kms.log_cmk_arn
}

output "gitea_db_secret_arn" {
  value = module.secrets.gitea_db_secret_arn
}

output "soc_db_secret_arn" {
  value = module.secrets.soc_db_secret_arn
}

output "jwt_secret_arn" {
  value = module.secrets.jwt_secret_arn
}

output "neo4j_secret_arn" {
  value = module.secrets.neo4j_secret_arn
}

output "gitea_db_endpoint" {
  value = module.rds.gitea_db_endpoint
}

output "soc_auth_db_endpoint" {
  value = module.rds.soc_auth_db_endpoint
}

output "customer_data_bucket_id" {
  value = module.s3.customer_data_bucket_id
}

output "log_bucket_id" {
  value = module.s3.log_bucket_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "irsa_gitea_role_arn" {
  value = module.eks.irsa_gitea_role_arn
}

output "soc_collector_private_ip" {
  value = module.ec2_soc.collector_private_ip
}

output "soc_graph_private_ip" {
  value = module.ec2_soc.graph_private_ip
}

output "soc_api_private_ip" {
  value = module.ec2_soc.api_private_ip
}

output "prod_alb_dns_name" {
  value = module.alb.prod_alb_dns_name
}

output "prod_target_group_arn" {
  value = module.alb.prod_target_group_arn
}

output "soc_alb_dns_name" {
  value = module.alb.soc_alb_dns_name
}
