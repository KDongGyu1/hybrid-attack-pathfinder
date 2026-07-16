variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to authenticate with (~/.aws/credentials). null = default credential chain (env vars, default profile, instance role, etc.)"
  type        = string
  default     = "test2"
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

variable "analyst_ip_cidr" {
  description = "Analyst IP/CIDR allowed to reach the SOC dashboard ALB (e.g. \"1.2.3.4/32\")"
  type        = string
}

variable "eks_stage" {
  description = "Node group sizing (dev = Step1 t3.small x1, presentation = Step2 t3.medium x2 Multi-AZ)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "presentation"], var.eks_stage)
    error_message = "eks_stage must be \"dev\" or \"presentation\"."
  }
}

variable "acm_arn" {
  description = "ACM certificate ARN for hap-soc-alb HTTPS listener (issued manually, out of Terraform scope)"
  type        = string
}

variable "iam_mode" {
  description = "S1/S4 IAM 시나리오 배포 단계: \"vulnerable\"(발표 시연용 취약 초기 상태) 또는 \"remediated\"(대응 우선순위 적용 후 최소 권한 상태)"
  type        = string
  default     = "vulnerable"

  validation {
    condition     = contains(["vulnerable", "remediated"], var.iam_mode)
    error_message = "iam_mode must be \"vulnerable\" or \"remediated\"."
  }
}
