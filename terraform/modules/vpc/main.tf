## ---------------------------------------------------------------------------
## VPC
## ---------------------------------------------------------------------------

resource "aws_vpc" "prod" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "hap-prod-vpc" }
}

resource "aws_vpc" "soc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "hap-soc-vpc" }
}

## ---------------------------------------------------------------------------
## Subnets — 3 tiers x 2 AZ x 2 VPC = 12
## ---------------------------------------------------------------------------

resource "aws_subnet" "prod_pub_2a" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "hap-prod-pub-2a" }
}

resource "aws_subnet" "prod_pub_2c" {
  vpc_id                  = aws_vpc.prod.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "hap-prod-pub-2c" }
}

resource "aws_subnet" "prod_app_2a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = var.azs[0]
  tags              = { Name = "hap-prod-app-2a" }
}

resource "aws_subnet" "prod_app_2c" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = var.azs[1]
  tags              = { Name = "hap-prod-app-2c" }
}

resource "aws_subnet" "prod_db_2a" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = var.azs[0]
  tags              = { Name = "hap-prod-db-2a" }
}

resource "aws_subnet" "prod_db_2c" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = "10.0.31.0/24"
  availability_zone = var.azs[1]
  tags              = { Name = "hap-prod-db-2c" }
}

resource "aws_subnet" "soc_pub_2a" {
  vpc_id                  = aws_vpc.soc.id
  cidr_block              = "10.1.10.0/24"
  availability_zone       = var.azs[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "hap-soc-pub-2a" }
}

resource "aws_subnet" "soc_pub_2c" {
  vpc_id                  = aws_vpc.soc.id
  cidr_block              = "10.1.11.0/24"
  availability_zone       = var.azs[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "hap-soc-pub-2c" }
}

resource "aws_subnet" "soc_app_2a" {
  vpc_id            = aws_vpc.soc.id
  cidr_block        = "10.1.20.0/24"
  availability_zone = var.azs[0]
  tags              = { Name = "hap-soc-app-2a" }
}

resource "aws_subnet" "soc_app_2c" {
  vpc_id            = aws_vpc.soc.id
  cidr_block        = "10.1.21.0/24"
  availability_zone = var.azs[1]
  tags              = { Name = "hap-soc-app-2c" }
}

resource "aws_subnet" "soc_db_2a" {
  vpc_id            = aws_vpc.soc.id
  cidr_block        = "10.1.30.0/24"
  availability_zone = var.azs[0]
  tags              = { Name = "hap-soc-db-2a" }
}

resource "aws_subnet" "soc_db_2c" {
  vpc_id            = aws_vpc.soc.id
  cidr_block        = "10.1.31.0/24"
  availability_zone = var.azs[1]
  tags              = { Name = "hap-soc-db-2c" }
}

## ---------------------------------------------------------------------------
## Internet Gateways
## ---------------------------------------------------------------------------

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-igw" }
}

resource "aws_internet_gateway" "soc" {
  vpc_id = aws_vpc.soc.id
  tags   = { Name = "hap-soc-igw" }
}

## ---------------------------------------------------------------------------
## NAT Gateways — Prod: 2a always, 2c only when prod_nat_count = 2. SOC: 1 (2a).
## ---------------------------------------------------------------------------

resource "aws_eip" "prod_nat_2a" {
  domain = "vpc"
  tags   = { Name = "hap-prod-nat-2a-eip" }
}

resource "aws_nat_gateway" "prod_2a" {
  allocation_id = aws_eip.prod_nat_2a.id
  subnet_id     = aws_subnet.prod_pub_2a.id
  tags          = { Name = "hap-prod-nat-2a" }

  depends_on = [aws_internet_gateway.prod]
}

resource "aws_eip" "prod_nat_2c" {
  count  = var.prod_nat_count == 2 ? 1 : 0
  domain = "vpc"
  tags   = { Name = "hap-prod-nat-2c-eip" }
}

resource "aws_nat_gateway" "prod_2c" {
  count         = var.prod_nat_count == 2 ? 1 : 0
  allocation_id = aws_eip.prod_nat_2c[0].id
  subnet_id     = aws_subnet.prod_pub_2c.id
  tags          = { Name = "hap-prod-nat-2c" }

  depends_on = [aws_internet_gateway.prod]
}

resource "aws_eip" "soc_nat" {
  domain = "vpc"
  tags   = { Name = "hap-soc-nat-eip" }
}

resource "aws_nat_gateway" "soc" {
  allocation_id = aws_eip.soc_nat.id
  subnet_id     = aws_subnet.soc_pub_2a.id
  tags          = { Name = "hap-soc-nat" }

  depends_on = [aws_internet_gateway.soc]
}

## ---------------------------------------------------------------------------
## VPC Peering — hap-soc-vpc <-> hap-prod-vpc (single account, auto-accept)
## ---------------------------------------------------------------------------

resource "aws_vpc_peering_connection" "prod_soc" {
  vpc_id      = aws_vpc.soc.id
  peer_vpc_id = aws_vpc.prod.id
  auto_accept = true

  tags = { Name = "hap-prod-soc-peering" }
}

## ---------------------------------------------------------------------------
## Route Tables
## ---------------------------------------------------------------------------

# Prod Public
resource "aws_route_table" "prod_pub" {
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-pub-rt" }
}

resource "aws_route" "prod_pub_igw" {
  route_table_id         = aws_route_table.prod_pub.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.prod.id
}

resource "aws_route" "prod_pub_peering" {
  route_table_id            = aws_route_table.prod_pub.id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table_association" "prod_pub_2a" {
  subnet_id      = aws_subnet.prod_pub_2a.id
  route_table_id = aws_route_table.prod_pub.id
}

resource "aws_route_table_association" "prod_pub_2c" {
  subnet_id      = aws_subnet.prod_pub_2c.id
  route_table_id = aws_route_table.prod_pub.id
}

# Prod Private-App — shared table when prod_nat_count = 1, per-AZ tables when = 2
resource "aws_route_table" "prod_app" {
  count  = var.prod_nat_count == 1 ? 1 : 0
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-app-rt" }
}

resource "aws_route" "prod_app_nat" {
  count                  = var.prod_nat_count == 1 ? 1 : 0
  route_table_id         = aws_route_table.prod_app[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.prod_2a.id
}

resource "aws_route" "prod_app_peering" {
  count                     = var.prod_nat_count == 1 ? 1 : 0
  route_table_id            = aws_route_table.prod_app[0].id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table" "prod_app_2a" {
  count  = var.prod_nat_count == 2 ? 1 : 0
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-app-rt-2a" }
}

resource "aws_route" "prod_app_2a_nat" {
  count                  = var.prod_nat_count == 2 ? 1 : 0
  route_table_id         = aws_route_table.prod_app_2a[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.prod_2a.id
}

resource "aws_route" "prod_app_2a_peering" {
  count                     = var.prod_nat_count == 2 ? 1 : 0
  route_table_id            = aws_route_table.prod_app_2a[0].id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table" "prod_app_2c" {
  count  = var.prod_nat_count == 2 ? 1 : 0
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-app-rt-2c" }
}

resource "aws_route" "prod_app_2c_nat" {
  count                  = var.prod_nat_count == 2 ? 1 : 0
  route_table_id         = aws_route_table.prod_app_2c[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.prod_2c[0].id
}

resource "aws_route" "prod_app_2c_peering" {
  count                     = var.prod_nat_count == 2 ? 1 : 0
  route_table_id            = aws_route_table.prod_app_2c[0].id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table_association" "prod_app_2a" {
  subnet_id      = aws_subnet.prod_app_2a.id
  route_table_id = concat(aws_route_table.prod_app[*].id, aws_route_table.prod_app_2a[*].id)[0]
}

resource "aws_route_table_association" "prod_app_2c" {
  subnet_id      = aws_subnet.prod_app_2c.id
  route_table_id = concat(aws_route_table.prod_app[*].id, aws_route_table.prod_app_2c[*].id)[0]
}

# Prod Private-DB — local only, no external route
resource "aws_route_table" "prod_db" {
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hap-prod-db-rt" }
}

resource "aws_route_table_association" "prod_db_2a" {
  subnet_id      = aws_subnet.prod_db_2a.id
  route_table_id = aws_route_table.prod_db.id
}

resource "aws_route_table_association" "prod_db_2c" {
  subnet_id      = aws_subnet.prod_db_2c.id
  route_table_id = aws_route_table.prod_db.id
}

# SOC Public
resource "aws_route_table" "soc_pub" {
  vpc_id = aws_vpc.soc.id
  tags   = { Name = "hap-soc-pub-rt" }
}

resource "aws_route" "soc_pub_igw" {
  route_table_id         = aws_route_table.soc_pub.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.soc.id
}

resource "aws_route" "soc_pub_peering" {
  route_table_id            = aws_route_table.soc_pub.id
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table_association" "soc_pub_2a" {
  subnet_id      = aws_subnet.soc_pub_2a.id
  route_table_id = aws_route_table.soc_pub.id
}

resource "aws_route_table_association" "soc_pub_2c" {
  subnet_id      = aws_subnet.soc_pub_2c.id
  route_table_id = aws_route_table.soc_pub.id
}

# SOC Private-App — single shared table (SOC NAT is never toggled)
resource "aws_route_table" "soc_app" {
  vpc_id = aws_vpc.soc.id
  tags   = { Name = "hap-soc-app-rt" }
}

resource "aws_route" "soc_app_nat" {
  route_table_id         = aws_route_table.soc_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.soc.id
}

resource "aws_route" "soc_app_peering" {
  route_table_id            = aws_route_table.soc_app.id
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_soc.id
}

resource "aws_route_table_association" "soc_app_2a" {
  subnet_id      = aws_subnet.soc_app_2a.id
  route_table_id = aws_route_table.soc_app.id
}

resource "aws_route_table_association" "soc_app_2c" {
  subnet_id      = aws_subnet.soc_app_2c.id
  route_table_id = aws_route_table.soc_app.id
}

# SOC Private-DB — local only, no external route
resource "aws_route_table" "soc_db" {
  vpc_id = aws_vpc.soc.id
  tags   = { Name = "hap-soc-db-rt" }
}

resource "aws_route_table_association" "soc_db_2a" {
  subnet_id      = aws_subnet.soc_db_2a.id
  route_table_id = aws_route_table.soc_db.id
}

resource "aws_route_table_association" "soc_db_2c" {
  subnet_id      = aws_subnet.soc_db_2c.id
  route_table_id = aws_route_table.soc_db.id
}
