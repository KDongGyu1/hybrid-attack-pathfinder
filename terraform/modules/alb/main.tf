## ---------------------------------------------------------------------------
## hap-prod-alb — HTTP/80 -> Gitea Pod :3000. target_type=ip since targets are
## EKS pods; actual pod registration happens at deploy time (AWS Load Balancer
## Controller TargetGroupBinding, or manual), not here.
## ---------------------------------------------------------------------------

resource "aws_lb" "prod" {
  name               = "hap-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.prod_alb_sg_id]
  subnets            = var.prod_public_subnet_ids

  access_logs {
    bucket  = var.alb_log_bucket_id
    prefix  = "prod-alb"
    enabled = true
  }

  tags = { Name = "hap-prod-alb" }
}

resource "aws_lb_target_group" "prod_gitea" {
  name        = "hap-prod-gitea-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.prod_vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "hap-prod-gitea-tg" }
}

resource "aws_lb_listener" "prod_http" {
  load_balancer_arn = aws_lb.prod.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_gitea.arn
  }
}

## ---------------------------------------------------------------------------
## hap-soc-alb — HTTPS/443 -> hap-soc-api EC2 :3000
## ---------------------------------------------------------------------------

resource "aws_lb" "soc" {
  name               = "hap-soc-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.soc_alb_sg_id]
  subnets            = var.soc_public_subnet_ids

  access_logs {
    bucket  = var.alb_log_bucket_id
    prefix  = "soc-alb"
    enabled = true
  }

  tags = { Name = "hap-soc-alb" }
}

resource "aws_lb_target_group" "soc_api" {
  name        = "hap-soc-api-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.soc_vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "hap-soc-api-tg" }
}

resource "aws_lb_target_group_attachment" "soc_api" {
  target_group_arn = aws_lb_target_group.soc_api.arn
  target_id        = var.soc_api_instance_id
  port             = 3000
}

resource "aws_lb_listener" "soc_https" {
  load_balancer_arn = aws_lb.soc.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.soc_api.arn
  }
}
