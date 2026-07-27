output "collector_instance_id" {
  value = aws_instance.collector.id
}

output "collector_private_ip" {
  value = aws_instance.collector.private_ip
}

output "graph_instance_id" {
  value = aws_instance.graph.id
}

output "graph_private_ip" {
  value = aws_instance.graph.private_ip
}

output "api_instance_id" {
  value = aws_instance.api.id
}

output "api_private_ip" {
  value = aws_instance.api.private_ip
}
