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
