output "prod_vpc_id" {
  value = aws_vpc.prod.id
}

output "soc_vpc_id" {
  value = aws_vpc.soc.id
}

output "prod_public_subnet_ids" {
  value = [aws_subnet.prod_pub_2a.id, aws_subnet.prod_pub_2c.id]
}

output "prod_app_subnet_ids" {
  value = [aws_subnet.prod_app_2a.id, aws_subnet.prod_app_2c.id]
}

output "prod_db_subnet_ids" {
  value = [aws_subnet.prod_db_2a.id, aws_subnet.prod_db_2c.id]
}

output "soc_public_subnet_ids" {
  value = [aws_subnet.soc_pub_2a.id, aws_subnet.soc_pub_2c.id]
}

output "soc_app_subnet_ids" {
  value = [aws_subnet.soc_app_2a.id, aws_subnet.soc_app_2c.id]
}

output "soc_db_subnet_ids" {
  value = [aws_subnet.soc_db_2a.id, aws_subnet.soc_db_2c.id]
}

output "prod_igw_id" {
  value = aws_internet_gateway.prod.id
}

output "soc_igw_id" {
  value = aws_internet_gateway.soc.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.prod_soc.id
}
