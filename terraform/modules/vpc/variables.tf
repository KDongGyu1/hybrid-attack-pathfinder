variable "azs" {
  description = "Availability zones used across both VPCs (2-AZ)"
  type        = list(string)
}

variable "prod_nat_count" {
  description = "Number of NAT Gateways for Prod VPC (1 = dev, 2 = presentation/Multi-AZ)"
  type        = number

  validation {
    condition     = contains([1, 2], var.prod_nat_count)
    error_message = "prod_nat_count must be 1 (dev) or 2 (presentation)."
  }
}
