variable "iam_mode" {
  description = "S1/S4 IAM 시나리오 배포 단계: \"vulnerable\"(발표 시연용 취약 초기 상태) 또는 \"remediated\"(대응 우선순위 적용 후 최소 권한 상태)"
  type        = string

  validation {
    condition     = contains(["vulnerable", "remediated"], var.iam_mode)
    error_message = "iam_mode must be \"vulnerable\" or \"remediated\"."
  }
}

variable "customer_data_bucket_arn" {
  description = "hap-customer-data-s3 ARN (S1 공격 대상 자산)"
  type        = string
}

variable "irsa_gitea_role_name" {
  description = "hap-irsa-gitea-role 이름. 트러스트 정책(OIDC 연동)은 eks 모듈 소유이며, 이 모듈은 권한 정책만 붙인다"
  type        = string
}

variable "gitea_db_secret_arn" {
  description = "hap-db-secret ARN (S4 교정 버전에서 Gitea IRSA가 조회할 시크릿 범위)"
  type        = string
}

variable "prod_secrets_cmk_arn" {
  description = "hap-prod-secrets-cmk ARN (S4 교정 버전에서 Gitea IRSA가 복호화할 CMK — soc-secrets-cmk와 혼용 금지)"
  type        = string
}

variable "log_bucket_arn" {
  description = "hap-soc-log-s3 ARN (on-prem web/db 키의 로그 전송 대상, onprem/* prefix)"
  type        = string
}

variable "data_cmk_arn" {
  description = "hap-data-cmk ARN — hap-customer-data-s3 기본 SSE-KMS 암호화 키. PutObject 성공을 위해 on-prem web 키에 kms:GenerateDataKey 부여 필요"
  type        = string
}

variable "log_cmk_arn" {
  description = "hap-log-cmk ARN — hap-soc-log-s3 기본 SSE-KMS 암호화 키. PutObject 성공을 위해 on-prem web/db 키에 kms:GenerateDataKey 부여 필요"
  type        = string
}
