variable "prod_vpc_id" {
  description = "Prod VPC ID"
  type        = string
}

variable "soc_vpc_id" {
  description = "SOC VPC ID"
  type        = string
}

variable "soc_collector_cidr" {
  description = "CIDR representing hap-soc-collector's location, used as the scan-source for the Prod app SG (cross-VPC SG-ID references are not supported over VPC peering, so a CIDR is used instead). Pinned to hap-soc-collector's fixed private IP (10.1.20.10/32) per the infra spec."
  type        = string
  default     = "10.1.20.10/32"
}

variable "analyst_ip_cidr" {
  description = "Analyst IP/CIDR allowed to reach the SOC dashboard ALB (e.g. \"1.2.3.4/32\")"
  type        = string
}
