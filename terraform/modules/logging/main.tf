data "aws_caller_identity" "current" {}

## ---------------------------------------------------------------------------
## hap-soc-log-s3 bucket policy — grants CloudTrail/Config/VPC Flow Logs
## write access, each scoped to its own prefix.
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "log_bucket_policy" {
  statement {
    sid       = "CloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [var.log_bucket_arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.log_bucket_arn}/cloudtrail/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "ConfigAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [var.log_bucket_arn]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }

  statement {
    sid       = "ConfigWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.log_bucket_arn}/config/*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid       = "FlowLogsAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [var.log_bucket_arn]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "FlowLogsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${var.log_bucket_arn}/flowlogs/*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "log" {
  bucket = var.log_bucket_id
  policy = data.aws_iam_policy_document.log_bucket_policy.json
}

## ---------------------------------------------------------------------------
## hap-log-cmk key policy — grants the same 3 services permission to encrypt
## with the CMK (default key policy only allows the account root).
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "log_cmk_policy" {
  statement {
    sid       = "EnableRootAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowLoggingServicesEncrypt"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com", "config.amazonaws.com", "delivery.logs.amazonaws.com"]
    }
  }
}

resource "aws_kms_key_policy" "log" {
  key_id = var.log_cmk_arn
  policy = data.aws_iam_policy_document.log_cmk_policy.json
}

## ---------------------------------------------------------------------------
## CloudTrail — hap-soc-log-s3/cloudtrail/. Management events (all) +
## S3 Data Events scoped to hap-customer-data-s3 only.
## ---------------------------------------------------------------------------

resource "aws_cloudtrail" "main" {
  name           = "hap-cloudtrail"
  s3_bucket_name = var.log_bucket_id
  s3_key_prefix  = "cloudtrail"
  kms_key_id     = var.log_cmk_arn

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  advanced_event_selector {
    name = "Management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "S3 Data Events - hap-customer-data-s3"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field       = "resources.ARN"
      starts_with = ["${var.customer_data_bucket_arn}/"]
    }
  }

  tags = { Name = "hap-cloudtrail" }

  depends_on = [aws_s3_bucket_policy.log, aws_kms_key_policy.log]
}

## ---------------------------------------------------------------------------
## AWS Config — hap-soc-log-s3/config/. Records all supported resource types.
## ---------------------------------------------------------------------------

data "aws_iam_policy_document" "config_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "hap-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json
  tags               = { Name = "hap-config-role" }
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "main" {
  name     = "hap-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "hap-config-channel"
  s3_bucket_name = var.log_bucket_id
  s3_key_prefix  = "config"
  s3_kms_key_arn = var.log_cmk_arn

  depends_on = [aws_config_configuration_recorder.main, aws_s3_bucket_policy.log, aws_kms_key_policy.log]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

## ---------------------------------------------------------------------------
## VPC Flow Logs — Prod + SOC, both to hap-soc-log-s3/flowlogs/
## ---------------------------------------------------------------------------

resource "aws_flow_log" "prod" {
  vpc_id               = var.prod_vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.log_bucket_arn}/flowlogs/prod/"

  tags = { Name = "hap-prod-flowlog" }

  depends_on = [aws_s3_bucket_policy.log]
}

resource "aws_flow_log" "soc" {
  vpc_id               = var.soc_vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.log_bucket_arn}/flowlogs/soc/"

  tags = { Name = "hap-soc-flowlog" }

  depends_on = [aws_s3_bucket_policy.log]
}
