variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "azs" {
  description = "Availability zones used across both VPCs (2-AZ)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "prod_nat_count" {
  description = "Number of NAT Gateways for Prod VPC (1 = dev, 2 = presentation/Multi-AZ)"
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 2], var.prod_nat_count)
    error_message = "prod_nat_count must be 1 (dev) or 2 (presentation)."
  }
}
