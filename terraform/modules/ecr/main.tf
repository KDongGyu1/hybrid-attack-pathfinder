resource "aws_ecr_repository" "gitea" {
  name                 = "hap-ecr"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "hap-ecr" }
}
