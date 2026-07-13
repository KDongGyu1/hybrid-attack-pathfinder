locals {
  is_dev         = var.eks_stage == "dev"
  instance_types = local.is_dev ? ["t3.small"] : ["t3.medium"]
  desired_size   = local.is_dev ? 1 : 2
  min_size       = local.is_dev ? 1 : 2
  max_size       = 4
}

## ---------------------------------------------------------------------------
## hap-eks — cluster (K8s 1.29). No encryption_config: EKS secrets rely on
## AWS's always-on default encryption, per spec ("그 외는 AWS 관리형 기본 암호화").
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_cluster_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "hap-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_trust.json
  tags               = { Name = "hap-eks-cluster-role" }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Pre-created so retention_in_days applies; EKS would otherwise auto-create
# this log group with no expiry when control-plane logging is enabled.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/hap-eks/cluster"
  retention_in_days = 30
  tags              = { Name = "hap-eks-cluster-logs" }
}

resource "aws_eks_cluster" "main" {
  name     = "hap-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = var.prod_app_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = { Name = "hap-eks" }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy, aws_cloudwatch_log_group.cluster]
}

## ---------------------------------------------------------------------------
## OIDC provider — required for IRSA
## ---------------------------------------------------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = { Name = "hap-eks-oidc" }
}

## ---------------------------------------------------------------------------
## hap-nodegroup — dev: t3.small x1 / presentation: t3.medium x2, Multi-AZ
## Custom launch template attaches hap-prod-app-sg so the SG rules
## (ALB->3000, SOC scan) actually apply to the nodes.
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eks_node_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "hap-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_trust.json
  tags               = { Name = "hap-eks-node-role" }
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM access for all EC2/EKS nodes per spec (no Bastion, SSM Session Manager only)
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Fluent Bit/Container Insights -> CloudWatch (spec 7.2: EKS App/Gitea logs)
resource "aws_iam_role_policy_attachment" "node_cloudwatch_agent" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_launch_template" "node" {
  name_prefix = "hap-nodegroup-"

  network_interfaces {
    security_groups = [var.prod_app_sg_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "hap-nodegroup-node" }
  }

  tags = { Name = "hap-nodegroup-lt" }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "hap-nodegroup"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.prod_app_subnet_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = local.instance_types
  capacity_type   = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = local.desired_size
    min_size     = local.min_size
    max_size     = local.max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = { Name = "hap-nodegroup" }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]
}

## ---------------------------------------------------------------------------
## hap-irsa-gitea-role — IRSA trust only. Permissions (vulnerable/remediated)
## are attached in the IAM module (stage 8), keyed to var.iam_mode.
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_gitea_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:prod:gitea-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_gitea" {
  name               = "hap-irsa-gitea-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_gitea_trust.json
  tags               = { Name = "hap-irsa-gitea-role" }
}

## ---------------------------------------------------------------------------
## hap-alb-controller-role — IRSA for the AWS Load Balancer Controller
## add-on (ServiceAccount aws-load-balancer-controller, namespace kube-system).
## Needed so hap-prod-alb's target group can actually be bound to Gitea Pods
## (TargetGroupBinding), and is a cluster add-on, not part of the S1/S4
## vulnerable/remediated toggle, so full upstream permissions are granted here.
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "irsa_lb_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa_lb_controller" {
  name               = "hap-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_lb_controller_trust.json
  tags               = { Name = "hap-alb-controller-role" }
}

# Official upstream policy: kubernetes-sigs/aws-load-balancer-controller
resource "aws_iam_policy" "lb_controller" {
  name   = "hap-alb-controller-policy"
  policy = file("${path.module}/policies/lb_controller_iam_policy.json")
  tags   = { Name = "hap-alb-controller-policy" }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.irsa_lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
