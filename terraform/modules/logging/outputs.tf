output "cloudtrail_arn" {
  value = aws_cloudtrail.main.arn
}

output "config_recorder_name" {
  value = aws_config_configuration_recorder.main.name
}

output "prod_flow_log_id" {
  value = aws_flow_log.prod.id
}

output "soc_flow_log_id" {
  value = aws_flow_log.soc.id
}
