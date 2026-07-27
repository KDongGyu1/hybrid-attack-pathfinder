variable "data_cmk_arn" {
  description = "hap-data-cmk ARN, for hap-customer-data-s3 encryption"
  type        = string
}

variable "log_cmk_arn" {
  description = "hap-log-cmk ARN, for hap-soc-log-s3 encryption"
  type        = string
}
