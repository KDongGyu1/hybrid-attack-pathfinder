## ---------------------------------------------------------------------------
## hap-db-secret — Gitea DB (PostgreSQL) password. Encrypted with prod-secrets-cmk.
## ---------------------------------------------------------------------------

resource "random_password" "gitea_db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "gitea_db" {
  name       = "hap-db-secret"
  kms_key_id = var.prod_secrets_cmk_arn
  tags       = { Name = "hap-db-secret" }
}

resource "aws_secretsmanager_secret_version" "gitea_db" {
  secret_id     = aws_secretsmanager_secret.gitea_db.id
  secret_string = random_password.gitea_db.result
}

## ---------------------------------------------------------------------------
## hap-soc-db-secret — SOC RDS (auth) password. Encrypted with soc-secrets-cmk.
## ---------------------------------------------------------------------------

resource "random_password" "soc_db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "soc_db" {
  name       = "hap-soc-db-secret"
  kms_key_id = var.soc_secrets_cmk_arn
  tags       = { Name = "hap-soc-db-secret" }
}

resource "aws_secretsmanager_secret_version" "soc_db" {
  secret_id     = aws_secretsmanager_secret.soc_db.id
  secret_string = random_password.soc_db.result
}

## ---------------------------------------------------------------------------
## hap-soc-jwt-secret — API JWT signing keys. JSON {"access","refresh"} per
## spec (env JWT_ACCESS_SECRET / JWT_REFRESH_SECRET). Encrypted with soc-secrets-cmk.
## ---------------------------------------------------------------------------

resource "random_password" "jwt_access" {
  length  = 64
  special = false
}

resource "random_password" "jwt_refresh" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt" {
  name       = "hap-soc-jwt-secret"
  kms_key_id = var.soc_secrets_cmk_arn
  tags       = { Name = "hap-soc-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    access  = random_password.jwt_access.result
    refresh = random_password.jwt_refresh.result
  })
}

## ---------------------------------------------------------------------------
## hap-soc-neo4j-secret — Neo4j password. Encrypted with soc-secrets-cmk.
## ---------------------------------------------------------------------------

resource "random_password" "neo4j" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "neo4j" {
  name       = "hap-soc-neo4j-secret"
  kms_key_id = var.soc_secrets_cmk_arn
  tags       = { Name = "hap-soc-neo4j-secret" }
}

resource "aws_secretsmanager_secret_version" "neo4j" {
  secret_id     = aws_secretsmanager_secret.neo4j.id
  secret_string = random_password.neo4j.result
}
