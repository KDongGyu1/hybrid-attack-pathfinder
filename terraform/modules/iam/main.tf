locals {
  is_vulnerable = var.iam_mode == "vulnerable"
}

## ---------------------------------------------------------------------------
## Scenario 1 — IAM 계정 탈취 → S3
##   경로 A (직접 정책): hap-dev-01-user -> hap-s3-access-policy -> S3
##   경로 B (Role 전환): hap-dev-01-user -> hap-s3-readonly-role -> hap-s3-readonly-policy -> S3
## ---------------------------------------------------------------------------

resource "aws_iam_user" "dev_01" {
  name = "hap-dev-01-user"
  tags = { Name = "hap-dev-01-user" }
}

# 취약 버전: 활성 액세스 키 존재(장기 미교체 상태를 시연). 교정 버전에서는
# 90일 주기 교체·미사용 키 즉시 비활성화가 운영 절차이므로 Terraform에는
# 키 리소스를 만들지 않는 것으로 표현한다(교체/비활성화는 Terraform 밖 운영 영역).
resource "aws_iam_access_key" "dev_01" {
  count = local.is_vulnerable ? 1 : 0
  user  = aws_iam_user.dev_01.name
}

# 경로 A 권한 정책. 최소권한 원칙(README 설계 전제)에 따라 교정 버전에서는
# "직접 연결 정책 없음 — Role Assume만 허용"(3.3)이 최종 상태이므로, 취약
# 버전에서만 리소스를 만든다. 교정 버전에서 이 정책을 축소된 형태로 남겨두면
# 자산 수집 그래프에 HAS_POLICY 엣지 없는 고아 노드가 생겨 경로 A가 실제로
# 막혔다는 것을 오히려 흐린다.
resource "aws_iam_policy" "s3_access" {
  count       = local.is_vulnerable ? 1 : 0
  name        = "hap-s3-access-policy"
  description = "S1 경로 A — hap-dev-01-user 직접 연결 정책 (취약 버전 전용)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "OverPermissiveS3Access"
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = [var.customer_data_bucket_arn, "${var.customer_data_bucket_arn}/*"]
    }]
  })

  tags = { Name = "hap-s3-access-policy" }
}

resource "aws_iam_user_policy_attachment" "dev_01_s3_access" {
  count      = local.is_vulnerable ? 1 : 0
  user       = aws_iam_user.dev_01.name
  policy_arn = aws_iam_policy.s3_access[0].arn
}

# 경로 B: AssumeRole 트러스트. 교정 버전에서는 MFA 필수 + 세션 1시간 제한
# 조건을 추가해 무제한 Assume을 막는다.
data "aws_iam_policy_document" "s3_readonly_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.dev_01.arn]
    }

    dynamic "condition" {
      for_each = local.is_vulnerable ? [] : [1]
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }

    dynamic "condition" {
      for_each = local.is_vulnerable ? [] : [1]
      content {
        test     = "NumericLessThan"
        variable = "sts:DurationSeconds"
        values   = ["3600"]
      }
    }
  }
}

resource "aws_iam_role" "s3_readonly" {
  name               = "hap-s3-readonly-role"
  assume_role_policy = data.aws_iam_policy_document.s3_readonly_trust.json
  tags               = { Name = "hap-s3-readonly-role" }
}

# Assume 후 권한. 취약/교정 버전 동일 — 버전 구분은 트러스트 정책의
# MFA·세션 조건(위)에서만 이루어진다.
resource "aws_iam_policy" "s3_readonly" {
  name        = "hap-s3-readonly-policy"
  description = "S1 경로 B — hap-s3-readonly-role에 연결되는 S3 읽기 전용 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "S3ReadOnlyViaAssumedRole"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [var.customer_data_bucket_arn, "${var.customer_data_bucket_arn}/*"]
    }]
  })

  tags = { Name = "hap-s3-readonly-policy" }
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.s3_readonly.name
  policy_arn = aws_iam_policy.s3_readonly.arn
}

## ---------------------------------------------------------------------------
## Scenario 4 — EKS Pod 침해 → IRSA 상승 → S3/RDS/Secrets Manager
##   hap-irsa-gitea-role의 트러스트(OIDC federated, gitea-sa 바인딩)는 eks
##   모듈이 이미 소유하므로, 여기서는 hap-gitea-role-policy만 만들어 붙인다.
## ---------------------------------------------------------------------------

resource "aws_iam_policy" "gitea_role_policy" {
  name        = "hap-gitea-role-policy"
  description = "S4 — hap-irsa-gitea-role에 연결되는 Gitea Pod 권한"

  policy = local.is_vulnerable ? jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "OverPermissiveGiteaAccess"
      Effect   = "Allow"
      Action   = ["s3:*", "rds-db:connect", "secretsmanager:GetSecretValue", "kms:Decrypt"]
      Resource = "*"
    }]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GiteaSecretsAccess"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.gitea_db_secret_arn
      },
      {
        Sid      = "GiteaKmsDecrypt"
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = var.prod_secrets_cmk_arn
      }
    ]
  })

  tags = { Name = "hap-gitea-role-policy" }
}

resource "aws_iam_role_policy_attachment" "gitea_role_policy" {
  role       = var.irsa_gitea_role_name
  policy_arn = aws_iam_policy.gitea_role_policy.arn
}
