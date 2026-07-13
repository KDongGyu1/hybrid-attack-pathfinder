variable "log_bucket_id" {
  description = "hap-soc-log-s3 bucket name"
  type        = string
}

variable "log_bucket_arn" {
  description = "hap-soc-log-s3 bucket ARN"
  type        = string
}

variable "log_cmk_arn" {
  description = "hap-log-cmk ARN, used to encrypt CloudTrail/Config and to grant logging services kms:GenerateDataKey"
  type        = string
}

variable "customer_data_bucket_arn" {
  description = "hap-customer-data-s3 ARN - CloudTrail S3 Data Events are scoped to this bucket only"
  type        = string
}

variable "prod_vpc_id" {
  type = string
}

variable "soc_vpc_id" {
  type = string
}
