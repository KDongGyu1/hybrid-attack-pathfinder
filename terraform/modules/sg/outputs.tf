output "prod_alb_sg_id" {
  value = aws_security_group.prod_alb.id
}

output "prod_app_sg_id" {
  value = aws_security_group.prod_app.id
}

output "prod_db_sg_id" {
  value = aws_security_group.prod_db.id
}

output "soc_alb_sg_id" {
  value = aws_security_group.soc_alb.id
}

output "soc_server_sg_id" {
  value = aws_security_group.soc_server.id
}

output "soc_collector_sg_id" {
  value = aws_security_group.soc_collector.id
}

output "soc_db_sg_id" {
  value = aws_security_group.soc_db.id
}
