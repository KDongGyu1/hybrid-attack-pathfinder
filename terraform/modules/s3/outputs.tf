output "customer_data_bucket_arn" {
  value = aws_s3_bucket.customer_data.arn
}

output "customer_data_bucket_id" {
  value = aws_s3_bucket.customer_data.id
}

output "log_bucket_arn" {
  value = aws_s3_bucket.log.arn
}

output "log_bucket_id" {
  value = aws_s3_bucket.log.id
}

output "alb_log_bucket_arn" {
  value = aws_s3_bucket.alb_log.arn
}

output "alb_log_bucket_id" {
  value      = aws_s3_bucket.alb_log.id
  depends_on = [aws_s3_bucket_policy.alb_log]
}
