## ---------------------------------------------------------------------------
## DB Subnet Groups — 2 AZ requirement, instances themselves are Single-AZ
## ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "prod" {
  name       = "hap-prod-db-subnet-group"
  subnet_ids = var.prod_db_subnet_ids
  tags       = { Name = "hap-prod-db-subnet-group" }
}

resource "aws_db_subnet_group" "soc" {
  name       = "hap-soc-db-subnet-group"
  subnet_ids = var.soc_db_subnet_ids
  tags       = { Name = "hap-soc-db-subnet-group" }
}

## ---------------------------------------------------------------------------
## hap-gitea-db — Prod, Gitea backend (PostgreSQL 16)
## ---------------------------------------------------------------------------

resource "aws_db_instance" "gitea" {
  identifier     = "hap-gitea-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.prod_rds_cmk_arn

  db_name  = "gitea"
  username = "gitea_admin"
  password = var.gitea_db_password

  db_subnet_group_name   = aws_db_subnet_group.prod.name
  vpc_security_group_ids = [var.prod_db_sg_id]
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = { Name = "hap-gitea-db" }
}

## ---------------------------------------------------------------------------
## hap-soc-auth-db — SOC, 사용자/인증/권한/감사로그 (PostgreSQL 16)
## ---------------------------------------------------------------------------

resource "aws_db_instance" "soc_auth" {
  identifier     = "hap-soc-auth-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.soc_rds_cmk_arn

  db_name  = "hybrid_attack_path"
  username = "postgres"
  password = var.soc_db_password

  db_subnet_group_name   = aws_db_subnet_group.soc.name
  vpc_security_group_ids = [var.soc_db_sg_id]
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = { Name = "hap-soc-auth-db" }
}
