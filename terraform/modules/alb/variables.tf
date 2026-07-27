variable "prod_vpc_id" {
  type = string
}

variable "soc_vpc_id" {
  type = string
}

variable "prod_public_subnet_ids" {
  type = list(string)
}

variable "soc_public_subnet_ids" {
  type = list(string)
}

variable "prod_alb_sg_id" {
  type = string
}

variable "soc_alb_sg_id" {
  type = string
}

variable "soc_api_instance_id" {
  description = "hap-soc-api EC2 instance ID, registered as the SOC ALB target"
  type        = string
}

variable "acm_arn" {
  description = "ACM certificate ARN for hap-soc-alb HTTPS listener (issued manually, out of Terraform scope). Empty string = listener not created yet."
  type        = string
  default     = ""
}

variable "alb_log_bucket_id" {
  description = "hap-alb-log-s3 bucket name, for ALB access log delivery"
  type        = string
}
