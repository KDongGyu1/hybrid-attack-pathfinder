output "gitea_db_endpoint" {
  value = aws_db_instance.gitea.endpoint
}

output "gitea_db_address" {
  value = aws_db_instance.gitea.address
}

output "soc_auth_db_endpoint" {
  value = aws_db_instance.soc_auth.endpoint
}

output "soc_auth_db_address" {
  value = aws_db_instance.soc_auth.address
}
