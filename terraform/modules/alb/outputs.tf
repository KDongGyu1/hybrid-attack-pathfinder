output "prod_alb_dns_name" {
  value = aws_lb.prod.dns_name
}

output "prod_alb_arn" {
  value = aws_lb.prod.arn
}

output "prod_target_group_arn" {
  value = aws_lb_target_group.prod_gitea.arn
}

output "soc_alb_dns_name" {
  value = aws_lb.soc.dns_name
}

output "soc_target_group_arn" {
  value = aws_lb_target_group.soc_api.arn
}
