variable "prod_secrets_cmk_arn" {
  description = "KMS CMK ARN used to encrypt Prod secrets (hap-prod-secrets-cmk)"
  type        = string
}

variable "soc_secrets_cmk_arn" {
  description = "KMS CMK ARN used to encrypt SOC secrets (hap-soc-secrets-cmk)"
  type        = string
}
