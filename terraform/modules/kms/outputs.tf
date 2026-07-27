output "prod_rds_cmk_arn" {
  value = aws_kms_key.prod_rds.arn
}

output "soc_rds_cmk_arn" {
  value = aws_kms_key.soc_rds.arn
}

output "prod_secrets_cmk_arn" {
  value = aws_kms_key.prod_secrets.arn
}

output "soc_secrets_cmk_arn" {
  value = aws_kms_key.soc_secrets.arn
}

output "data_cmk_arn" {
  value = aws_kms_key.data.arn
}

output "log_cmk_arn" {
  value = aws_kms_key.log.arn
}
