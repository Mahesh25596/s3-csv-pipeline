# ============================================================================
# TERRAFORM CONFIGURATION
# ============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# LOCALS
# ============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner_email
    CostCenter  = var.cost_center
    Backup      = var.backup_required ? "true" : "false"
    Compliance  = var.compliance_level
    CreatedBy   = "terraform"
    Repository  = var.repository_url
  }
  
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ============================================================================
# PROVIDER CONFIGURATION
# ============================================================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# ============================================================================
# RANDOM RESOURCES
# ============================================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ============================================================================
# KMS ENCRYPTION
# ============================================================================

resource "aws_kms_key" "s3_encryption" {
  description             = "${local.name_prefix} S3 encryption key"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_exec.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_kms_alias" "s3_encryption_alias" {
  name          = "alias/${local.name_prefix}-s3-encryption"
  target_key_id = aws_kms_key.s3_encryption.key_id
}

# ============================================================================
# S3 BUCKETS
# ============================================================================

# Input Bucket
resource "aws_s3_bucket" "input_bucket" {
  bucket        = "${local.name_prefix}-${var.input_bucket_name}-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy_buckets

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-input-bucket"
    Type = "Input"
  })
}

resource "aws_s3_bucket_versioning" "input_versioning" {
  bucket = aws_s3_bucket.input_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input_encryption" {
  bucket = aws_s3_bucket.input_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "input_access" {
  bucket = aws_s3_bucket.input_bucket.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "input_lifecycle" {
  bucket = aws_s3_bucket.input_bucket.id

  rule {
    id     = "transition_and_cleanup"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "input_bucket_policy" {
  bucket = aws_s3_bucket.input_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          "${aws_s3_bucket.input_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Processed Bucket
resource "aws_s3_bucket" "processed_bucket" {
  bucket        = "${local.name_prefix}-${var.processed_bucket_name}-${random_id.bucket_suffix.hex}"
  force_destroy = var.force_destroy_buckets

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-processed-bucket"
    Type = "Processed"
  })
}

resource "aws_s3_bucket_versioning" "processed_versioning" {
  bucket = aws_s3_bucket.processed_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_encryption" {
  bucket = aws_s3_bucket.processed_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "processed_access" {
  bucket = aws_s3_bucket.processed_bucket.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "processed_lifecycle" {
  bucket = aws_s3_bucket.processed_bucket.id

  rule {
    id     = "transition_and_cleanup"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }
}

resource "aws_s3_bucket_policy" "processed_bucket_policy" {
  bucket = aws_s3_bucket.processed_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.processed_bucket.arn,
          "${aws_s3_bucket.processed_bucket.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================================
# SNS FOR NOTIFICATIONS
# ============================================================================

resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = aws_kms_key.s3_encryption.arn

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ============================================================================
# SQS DEAD LETTER QUEUE
# ============================================================================

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${local.name_prefix}-lambda-dlq"
  message_retention_seconds = 1209600  # 14 days
  kms_master_key_id         = aws_kms_key.s3_encryption.arn

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "lambda_dlq_policy" {
  queue_url = aws_sqs_queue.lambda_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaSendMessage"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_exec.arn
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

# ============================================================================
# CLOUDWATCH LOG GROUP
# ============================================================================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}-processor"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.s3_encryption.arn

  tags = local.common_tags
}

# ============================================================================
# IAM ROLES AND POLICIES
# ============================================================================

resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${local.name_prefix}-lambda-policy"
  description = "Policy for Lambda to access S3, Athena, and other required services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:PutObjectTagging",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.input_bucket.arn}/*",
          "${aws_s3_bucket.processed_bucket.arn}/*"
        ]
      },
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.input_bucket.arn,
          aws_s3_bucket.processed_bucket.arn
        ]
      },
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = [
          "arn:aws:athena:${local.region}:${local.account_id}:workgroup/primary",
          "arn:aws:athena:${local.region}:${local.account_id}:datacatalog/*"
        ]
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:UpdateTable",
          "glue:CreateTable",
          "glue:GetPartitions"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.account_id}:database/${local.name_prefix}-db",
          "arn:aws:glue:${local.region}:${local.account_id}:table/${local.name_prefix}-db/*"
        ]
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_encryption.arn
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.lambda_dlq.arn
      },
      {
        Sid    = "SNSAccess"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.enable_vpc ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ============================================================================
# VPC RESOURCES (OPTIONAL)
# ============================================================================

resource "aws_security_group" "lambda_sg" {
  count       = var.enable_vpc ? 1 : 0
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-sg"
  })
}

# ============================================================================
# LAMBDA FUNCTION
# ============================================================================

resource "aws_lambda_function" "csv_processor" {
  function_name = "${local.name_prefix}-processor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = {
      PROCESSED_BUCKET    = aws_s3_bucket.processed_bucket.id
      ATHENA_DATABASE     = aws_glue_catalog_database.csv_processor_db.name
      ATHENA_TABLE        = aws_glue_catalog_table.processed_csv_data.name
      LOG_LEVEL          = var.log_level
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
      ENVIRONMENT        = var.environment
      KMS_KEY_ID         = aws_kms_key.s3_encryption.arn
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  dynamic "vpc_config" {
    for_each = var.enable_vpc ? [1] : []
    content {
      subnet_ids         = var.lambda_subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      filename,
      last_modified,
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_policy_attach,
    aws_iam_role_policy_attachment.lambda_basic,
  ]

  tags = local.common_tags
}

# ============================================================================
# LAMBDA PERMISSIONS AND TRIGGERS
# ============================================================================

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_processor.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

# ============================================================================
# ATHENA RESOURCES
# ============================================================================

resource "aws_glue_catalog_database" "csv_processor_db" {
  name        = "${local.name_prefix}-db"
  description = "Database for CSV processing pipeline"
  
  catalog_id = local.account_id
}

resource "aws_glue_catalog_table" "processed_csv_data" {
  name          = "processed_data"
  database_name = aws_glue_catalog_database.csv_processor_db.name
  table_type    = "EXTERNAL_TABLE"
  catalog_id    = local.account_id

  parameters = {
    EXTERNAL                 = "TRUE"
    "skip.header.line.count" = "1"
    "projection.enabled"     = var.enable_athena_partitioning ? "true" : "false"
    "projection.date.type"   = var.enable_athena_partitioning ? "date" : ""
    "projection.date.range"  = var.enable_athena_partitioning ? "2020/01/01,NOW" : ""
    "projection.date.format" = var.enable_athena_partitioning ? "yyyy/MM/dd" : ""
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.processed_bucket.id}/processed/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      name                  = "csv"
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar" = ","
        "quoteChar"     = "\""
        "escapeChar"    = "\\"
      }
    }

    dynamic "columns" {
      for_each = var.table_columns
      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }
}

# ============================================================================
# CLOUDWATCH MONITORING
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.csv_processor.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.name_prefix}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.lambda_timeout * 1000 * 0.8  # 80% of timeout
  alarm_description   = "This metric monitors lambda duration"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.csv_processor.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name_prefix}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors messages in DLQ"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.lambda_dlq.name
  }

  tags = local.common_tags
}

# ============================================================================
# ATHENA WORKGROUP (OPTIONAL)
# ============================================================================

resource "aws_athena_workgroup" "csv_processor_workgroup" {
  count = var.create_athena_workgroup ? 1 : 0
  name  = "${local.name_prefix}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.processed_bucket.id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key       = aws_kms_key.s3_encryption.arn
      }
    }
  }

  tags = local.common_tags
}
