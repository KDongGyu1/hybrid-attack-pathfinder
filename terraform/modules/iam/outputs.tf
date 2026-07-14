output "dev_01_user_arn" {
  value = aws_iam_user.dev_01.arn
}

output "dev_01_access_key_id" {
  value = local.is_vulnerable ? aws_iam_access_key.dev_01[0].id : null
}

output "dev_01_access_key_secret" {
  value     = local.is_vulnerable ? aws_iam_access_key.dev_01[0].secret : null
  sensitive = true
}

output "s3_readonly_role_arn" {
  value = aws_iam_role.s3_readonly.arn
}

output "gitea_role_policy_arn" {
  value = aws_iam_policy.gitea_role_policy.arn
}

output "onprem_web_user_arn" {
  value = aws_iam_user.onprem_web.arn
}

output "onprem_web_access_key_id" {
  value = aws_iam_access_key.onprem_web.id
}

output "onprem_web_access_key_secret" {
  value     = aws_iam_access_key.onprem_web.secret
  sensitive = true
}

output "onprem_db_user_arn" {
  value = aws_iam_user.onprem_db.arn
}

output "onprem_db_access_key_id" {
  value = aws_iam_access_key.onprem_db.id
}

output "onprem_db_access_key_secret" {
  value     = aws_iam_access_key.onprem_db.secret
  sensitive = true
}
