output "gitea_db_secret_arn" {
  value = aws_secretsmanager_secret.gitea_db.arn
}

output "gitea_db_password" {
  value     = random_password.gitea_db.result
  sensitive = true
}

output "soc_db_secret_arn" {
  value = aws_secretsmanager_secret.soc_db.arn
}

output "soc_db_password" {
  value     = random_password.soc_db.result
  sensitive = true
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt.arn
}

output "neo4j_secret_arn" {
  value = aws_secretsmanager_secret.neo4j.arn
}
