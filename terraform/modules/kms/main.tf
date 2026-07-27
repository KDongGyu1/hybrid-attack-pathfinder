## ---------------------------------------------------------------------------
## KMS CMKs — 6 keys, Prod/SOC trust-boundary separated per spec
## ---------------------------------------------------------------------------

resource "aws_kms_key" "prod_rds" {
  description             = "hap-prod-rds-cmk - Prod RDS (hap-gitea-db) storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-prod-rds-cmk" }
}

resource "aws_kms_alias" "prod_rds" {
  name          = "alias/hap-prod-rds-cmk"
  target_key_id = aws_kms_key.prod_rds.key_id
}

resource "aws_kms_key" "soc_rds" {
  description             = "hap-soc-rds-cmk - SOC RDS (hap-soc-auth-db) storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-soc-rds-cmk" }
}

resource "aws_kms_alias" "soc_rds" {
  name          = "alias/hap-soc-rds-cmk"
  target_key_id = aws_kms_key.soc_rds.key_id
}

resource "aws_kms_key" "prod_secrets" {
  description             = "hap-prod-secrets-cmk - Prod secrets (hap-db-secret) encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-prod-secrets-cmk" }
}

resource "aws_kms_alias" "prod_secrets" {
  name          = "alias/hap-prod-secrets-cmk"
  target_key_id = aws_kms_key.prod_secrets.key_id
}

resource "aws_kms_key" "soc_secrets" {
  description             = "hap-soc-secrets-cmk - SOC secrets (db/jwt/neo4j) encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-soc-secrets-cmk" }
}

resource "aws_kms_alias" "soc_secrets" {
  name          = "alias/hap-soc-secrets-cmk"
  target_key_id = aws_kms_key.soc_secrets.key_id
}

resource "aws_kms_key" "data" {
  description             = "hap-data-cmk - hap-customer-data-s3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-data-cmk" }
}

resource "aws_kms_alias" "data" {
  name          = "alias/hap-data-cmk"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_kms_key" "log" {
  description             = "hap-log-cmk - hap-soc-log-s3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "hap-log-cmk" }
}

resource "aws_kms_alias" "log" {
  name          = "alias/hap-log-cmk"
  target_key_id = aws_kms_key.log.key_id
}
