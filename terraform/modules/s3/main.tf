## ---------------------------------------------------------------------------
## hap-customer-data-s3 — customer data (dummy) + on-prem WordPress backup target
## SSE-KMS(hap-data-cmk), public access blocked. S3 Data Events -> stage 7 (logging).
## ---------------------------------------------------------------------------

resource "aws_s3_bucket" "customer_data" {
  bucket = "hap-customer-data-s3"
  tags   = { Name = "hap-customer-data-s3" }
}

resource "aws_s3_bucket_public_access_block" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "customer_data" {
  bucket = aws_s3_bucket.customer_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.data_cmk_arn
    }
    bucket_key_enabled = true
  }
}

## ---------------------------------------------------------------------------
## hap-soc-log-s3 — centralized log archive
## SSE-KMS(hap-log-cmk), versioning + Object Lock(GOVERNANCE, 90d) for integrity,
## Lifecycle: 30d -> STANDARD_IA, expire at 90d (aligned with Object Lock retention).
## ---------------------------------------------------------------------------

resource "aws_s3_bucket" "log" {
  bucket              = "hap-soc-log-s3"
  object_lock_enabled = true
  tags                = { Name = "hap-soc-log-s3" }
}

resource "aws_s3_bucket_versioning" "log" {
  bucket = aws_s3_bucket.log.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.log_cmk_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "log" {
  bucket = aws_s3_bucket.log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.log]
}

## ---------------------------------------------------------------------------
## hap-soc-alb-log-s3 — ALB access logs only (Prod+SOC). SSE-S3 (AES256): ELB
## access log delivery does not support SSE-KMS destination buckets, so this
## is kept separate from hap-soc-log-s3 (which is SSE-KMS).
## ---------------------------------------------------------------------------

resource "aws_s3_bucket" "alb_log" {
  bucket = "hap-soc-alb-log-s3"
  tags   = { Name = "hap-soc-alb-log-s3" }
}

resource "aws_s3_bucket_versioning" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_log" {
  bucket = aws_s3_bucket.alb_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log" {
  bucket = aws_s3_bucket.log.id

  rule {
    id     = "log-transition-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }

  depends_on = [aws_s3_bucket_versioning.log]
}
