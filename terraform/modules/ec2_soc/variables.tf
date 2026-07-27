variable "soc_app_subnet_ids" {
  description = "SOC Private-App subnet IDs [2a, 2c] - all 3 servers pinned to 2a per spec"
  type        = list(string)
}

variable "soc_collector_sg_id" {
  description = "hap-soc-collector-sg ID"
  type        = string
}

variable "soc_server_sg_id" {
  description = "hap-soc-server-sg ID (graph + api)"
  type        = string
}

variable "soc_secrets_cmk_arn" {
  description = "hap-soc-secrets-cmk ARN, for kms:Decrypt on graph/api secrets"
  type        = string
}

variable "soc_db_secret_arn" {
  description = "hap-soc-db-secret ARN (api server)"
  type        = string
}

variable "jwt_secret_arn" {
  description = "hap-soc-jwt-secret ARN (api server)"
  type        = string
}

variable "neo4j_secret_arn" {
  description = "hap-soc-neo4j-secret ARN (graph server)"
  type        = string
}
