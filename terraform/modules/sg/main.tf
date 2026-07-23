## ---------------------------------------------------------------------------
## Security Groups
## ---------------------------------------------------------------------------

resource "aws_security_group" "prod_alb" {
  name        = "hap-prod-alb-sg"
  description = "Prod ALB - public HTTP/HTTPS"
  vpc_id      = var.prod_vpc_id
  tags        = { Name = "hap-prod-alb-sg" }
}

resource "aws_security_group" "prod_app" {
  name        = "hap-prod-app-sg"
  description = "Prod EKS/Gitea - ALB to app, SOC Nmap scan"
  vpc_id      = var.prod_vpc_id
  tags        = { Name = "hap-prod-app-sg" }
}

resource "aws_security_group" "prod_db" {
  name        = "hap-prod-db-sg"
  description = "Prod RDS - app to DB"
  vpc_id      = var.prod_vpc_id
  tags        = { Name = "hap-prod-db-sg" }
}

resource "aws_security_group" "soc_alb" {
  name        = "hap-soc-alb-sg"
  description = "SOC dashboard ALB - analyst IP only"
  vpc_id      = var.soc_vpc_id
  tags        = { Name = "hap-soc-alb-sg" }
}

resource "aws_security_group" "soc_server" {
  name        = "hap-soc-server-sg"
  description = "SOC graph/api servers - mutual + ALB"
  vpc_id      = var.soc_vpc_id
  tags        = { Name = "hap-soc-server-sg" }
}

resource "aws_security_group" "soc_collector" {
  name        = "hap-soc-collector-sg"
  description = "SOC collector - outbound scan/API collection only, no inbound"
  vpc_id      = var.soc_vpc_id
  tags        = { Name = "hap-soc-collector-sg" }
}

resource "aws_security_group" "soc_db" {
  name        = "hap-soc-db-sg"
  description = "SOC RDS (auth) - server to DB"
  vpc_id      = var.soc_vpc_id
  tags        = { Name = "hap-soc-db-sg" }
}

## ---------------------------------------------------------------------------
## Ingress rules
## ---------------------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "prod_alb_http" {
  security_group_id = aws_security_group.prod_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "prod_alb_https" {
  security_group_id = aws_security_group.prod_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "prod_app_from_alb" {
  security_group_id            = aws_security_group.prod_app.id
  referenced_security_group_id = aws_security_group.prod_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_ingress_rule" "prod_app_from_soc_scan" {
  security_group_id = aws_security_group.prod_app.id
  cidr_ipv4         = var.soc_collector_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "prod_db_from_app" {
  security_group_id            = aws_security_group.prod_db.id
  referenced_security_group_id = aws_security_group.prod_app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "soc_alb_https" {
  security_group_id = aws_security_group.soc_alb.id
  cidr_ipv4         = var.analyst_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_from_alb_3000" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_alb.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_self_3000" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_server.id
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_self_neo4j_http" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_server.id
  ip_protocol                  = "tcp"
  from_port                    = 7474
  to_port                      = 7474
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_self_neo4j_bolt" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_server.id
  ip_protocol                  = "tcp"
  from_port                    = 7687
  to_port                      = 7687
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_self_fastapi" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_server.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

resource "aws_vpc_security_group_ingress_rule" "soc_server_from_collector_fastapi" {
  security_group_id            = aws_security_group.soc_server.id
  referenced_security_group_id = aws_security_group.soc_collector.id
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

resource "aws_vpc_security_group_ingress_rule" "soc_db_from_server" {
  security_group_id            = aws_security_group.soc_db.id
  referenced_security_group_id = aws_security_group.soc_server.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

## ---------------------------------------------------------------------------
## Egress rules — allow all outbound for every SG (not restricted by spec)
## ---------------------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "prod_alb_all" {
  security_group_id = aws_security_group.prod_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "prod_app_all" {
  security_group_id = aws_security_group.prod_app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "prod_db_all" {
  security_group_id = aws_security_group.prod_db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "soc_alb_all" {
  security_group_id = aws_security_group.soc_alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "soc_server_all" {
  security_group_id = aws_security_group.soc_server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "soc_collector_all" {
  security_group_id = aws_security_group.soc_collector.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "soc_db_all" {
  security_group_id = aws_security_group.soc_db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
