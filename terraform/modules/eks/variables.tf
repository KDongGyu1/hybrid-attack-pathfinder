variable "prod_app_subnet_ids" {
  description = "Prod Private-App subnet IDs (2 AZ) - cluster + node group placement"
  type        = list(string)
}

variable "prod_app_sg_id" {
  description = "hap-prod-app-sg ID, attached to node ENIs (ALB->app:3000, SOC scan rule)"
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
