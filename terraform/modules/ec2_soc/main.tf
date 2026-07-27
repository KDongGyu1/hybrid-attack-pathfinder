data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

## ---------------------------------------------------------------------------
## CloudWatch Log Groups — one per SOC server (CloudWatch Agent target, OS/app
## logs per spec 7.2). Not auto-created by AWS, so no ordering hazard.
## ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/hap/soc-collector"
  retention_in_days = 30
  tags              = { Name = "hap-soc-collector-logs" }
}

resource "aws_cloudwatch_log_group" "graph" {
  name              = "/hap/soc-graph"
  retention_in_days = 30
  tags              = { Name = "hap-soc-graph-logs" }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/hap/soc-api"
  retention_in_days = 30
  tags              = { Name = "hap-soc-api-logs" }
}

## ---------------------------------------------------------------------------
## hap-soc-collector — Nmap/Trivy/Scout Suite/AWS CLI/Config/Python. No
## Secrets Manager use per spec. SecurityAudit covers its read-only AWS
## collection role (Config/IAM/EC2/S3/RDS describe-type access).
## ---------------------------------------------------------------------------

resource "aws_iam_role" "collector" {
  name               = "hap-soc-collector-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { Name = "hap-soc-collector-role" }
}

resource "aws_iam_role_policy_attachment" "collector_ssm" {
  role       = aws_iam_role.collector.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "collector_security_audit" {
  role       = aws_iam_role.collector.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_role_policy_attachment" "collector_cloudwatch_agent" {
  role       = aws_iam_role.collector.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "collector" {
  name = "hap-soc-collector-profile"
  role = aws_iam_role.collector.name
}

resource "aws_instance" "collector" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.small"
  subnet_id                   = var.soc_app_subnet_ids[0]
  private_ip                  = "10.1.20.10"
  vpc_security_group_ids      = [var.soc_collector_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.collector.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "hap-soc-collector" }
}

## ---------------------------------------------------------------------------
## hap-soc-graph — Neo4j + 탐색 엔진. Reads hap-soc-neo4j-secret.
## ---------------------------------------------------------------------------

resource "aws_iam_role" "graph" {
  name               = "hap-soc-graph-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { Name = "hap-soc-graph-role" }
}

resource "aws_iam_role_policy_attachment" "graph_ssm" {
  role       = aws_iam_role.graph.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "graph_cloudwatch_agent" {
  role       = aws_iam_role.graph.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "graph_secret" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.neo4j_secret_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.soc_secrets_cmk_arn]
  }
}

resource "aws_iam_role_policy" "graph_secret" {
  name   = "hap-soc-graph-secret-policy"
  role   = aws_iam_role.graph.id
  policy = data.aws_iam_policy_document.graph_secret.json
}

resource "aws_iam_instance_profile" "graph" {
  name = "hap-soc-graph-profile"
  role = aws_iam_role.graph.name
}

resource "aws_instance" "graph" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.small"
  subnet_id                   = var.soc_app_subnet_ids[0]
  private_ip                  = "10.1.20.20"
  vpc_security_group_ids      = [var.soc_server_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.graph.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "hap-soc-graph" }
}

## ---------------------------------------------------------------------------
## hap-soc-api — API(NestJS/JWT) + 프론트. Reads hap-soc-db-secret + hap-soc-jwt-secret.
## ---------------------------------------------------------------------------

resource "aws_iam_role" "api" {
  name               = "hap-soc-api-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { Name = "hap-soc-api-role" }
}

resource "aws_iam_role_policy_attachment" "api_ssm" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "api_cloudwatch_agent" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "api_secret" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.soc_db_secret_arn, var.jwt_secret_arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.soc_secrets_cmk_arn]
  }
}

resource "aws_iam_role_policy" "api_secret" {
  name   = "hap-soc-api-secret-policy"
  role   = aws_iam_role.api.id
  policy = data.aws_iam_policy_document.api_secret.json
}

resource "aws_iam_instance_profile" "api" {
  name = "hap-soc-api-profile"
  role = aws_iam_role.api.name
}

resource "aws_instance" "api" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.small"
  subnet_id                   = var.soc_app_subnet_ids[0]
  private_ip                  = "10.1.20.30"
  vpc_security_group_ids      = [var.soc_server_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.api.name
  associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "hap-soc-api" }
}
