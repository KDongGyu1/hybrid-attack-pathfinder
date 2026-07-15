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

## ---------------------------------------------------------------------------
## Scenario 1/3 — On-Prem 침해 → IAM Access Key 탈취 → S3
##   hap-onprem-web-user: 백업(hap-customer-data-s3) + web 로그 전송용, S1/S3의 탈취 대상 키.
##     취약 버전 = 광범위 S3 권한, 교정 버전 = PutObject 최소권한(버킷 정책은 단일 계정이라
##     불필요 — 인프라 쪽 리소스 정책이 아닌 이 identity 정책만으로 충분).
##   hap-onprem-db-user : db 로그 전송 전용 최소권한 고정(취약/교정 구분 없음). customer-data 접근이
##     없어 유출돼도 무해하므로 공격 경로 그래프에는 포함되지 않는다.
##   이름에 -user 접미사를 붙이는 이유: hap-onprem-web/hap-onprem-db는 이미 backend1
##   Neo4j 그래프에서 물리 서버(OnPremWeb/OnPremDB) 노드 ID로 쓰이고 있어 충돌한다.
## ---------------------------------------------------------------------------

resource "aws_iam_user" "onprem_web" {
  name = "hap-onprem-web-user"
  tags = { Name = "hap-onprem-web-user" }
}

# 실제 백업/로그 자동화가 두 모드 모두에서 동작해야 하므로(dev_01과 달리 키 자체를
# 제거하지 않음), 버전 구분은 아래 정책 권한 범위로만 표현한다.
resource "aws_iam_access_key" "onprem_web" {
  user = aws_iam_user.onprem_web.name
}

resource "aws_iam_policy" "onprem_web_s3" {
  name        = "hap-onprem-web-s3-policy"
  description = "S1/S3 탈취 대상 키(hap-onprem-web-user) 권한 — 취약: 광범위 S3 접근 / 교정: 백업·로그 PutObject 최소권한"

  # 두 버킷 모두 기본 SSE-KMS 암호화가 강제되어 있어(s3 모듈), s3:PutObject/GetObject가
  # 실제로 성공하려면 해당 CMK에 대한 kms 권한이 identity 정책에도 있어야 한다
  # (hap-gitea-role-policy와 동일한 패턴).
  policy = local.is_vulnerable ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OverPermissiveOnpremWebS3Access"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      },
      {
        Sid      = "OnpremWebKmsForS3Sse"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey*", "kms:Decrypt"]
        Resource = [var.data_cmk_arn, var.log_cmk_arn]
      }
    ]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OnpremWebBackupAndLogPut"
        Effect = "Allow"
        Action = "s3:PutObject"
        # onprem/scripts/backup-to-s3.sh가 실제로 쓰는 두 프리픽스로 한정 (버킷 전체 접근 금지)
        Resource = [
          "${var.customer_data_bucket_arn}/wordpress-files/*",
          "${var.customer_data_bucket_arn}/wordpress-db/*",
          "${var.log_bucket_arn}/onprem/*",
        ]
      },
      {
        Sid      = "OnpremWebKmsForS3Sse"
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey*"
        Resource = [var.data_cmk_arn, var.log_cmk_arn]
      }
    ]
  })

  tags = { Name = "hap-onprem-web-s3-policy" }
}

resource "aws_iam_user_policy_attachment" "onprem_web_s3" {
  user       = aws_iam_user.onprem_web.name
  policy_arn = aws_iam_policy.onprem_web_s3.arn
}

resource "aws_iam_user" "onprem_db" {
  name = "hap-onprem-db-user"
  tags = { Name = "hap-onprem-db-user" }
}

resource "aws_iam_access_key" "onprem_db" {
  user = aws_iam_user.onprem_db.name
}

resource "aws_iam_policy" "onprem_db_s3" {
  name        = "hap-onprem-db-s3-policy"
  description = "무해한 키(hap-onprem-db-user) — hap-soc-log-s3/onprem/* 로그 전송 전용 최소권한, customer-data 접근 불가(취약/교정 구분 없음)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OnpremDbLogPutOnly"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${var.log_bucket_arn}/onprem/*"
      },
      {
        Sid      = "OnpremDbKmsForS3Sse"
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey*"
        Resource = var.log_cmk_arn
      }
    ]
  })

  tags = { Name = "hap-onprem-db-s3-policy" }
}

resource "aws_iam_user_policy_attachment" "onprem_db_s3" {
  user       = aws_iam_user.onprem_db.name
  policy_arn = aws_iam_policy.onprem_db_s3.arn
}
