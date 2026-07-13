variable "prod_db_subnet_ids" {
  description = "Prod Private-DB subnet IDs (2 AZ, for DB Subnet Group)"
  type        = list(string)
}

variable "soc_db_subnet_ids" {
  description = "SOC Private-DB subnet IDs (2 AZ, for DB Subnet Group)"
  type        = list(string)
}

variable "prod_db_sg_id" {
  description = "hap-prod-db-sg ID"
  type        = string
}

variable "soc_db_sg_id" {
  description = "hap-soc-db-sg ID"
  type        = string
}

variable "prod_rds_cmk_arn" {
  description = "hap-prod-rds-cmk ARN, for hap-gitea-db storage encryption"
  type        = string
}

variable "soc_rds_cmk_arn" {
  description = "hap-soc-rds-cmk ARN, for hap-soc-auth-db storage encryption"
  type        = string
}

variable "gitea_db_password" {
  description = "hap-gitea-db master password (from Secrets Manager hap-db-secret)"
  type        = string
  sensitive   = true
}

variable "soc_db_password" {
  description = "hap-soc-auth-db master password (from Secrets Manager hap-soc-db-secret)"
  type        = string
  sensitive   = true
}
