# ============================================================================
# OUTPUTS.TF - Enhanced Output Definitions
# ============================================================================

# ============================================================================
# S3 BUCKET OUTPUTS
# ============================================================================

output "input_bucket_name" {
  description = "Name of the input S3 bucket"
  value       = aws_s3_bucket.input_bucket.bucket
}

output "input_bucket_arn" {
  description = "ARN of the input S3 bucket"
  value       = aws_s3_bucket.input_bucket.arn
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed_bucket.bucket
}

output "processed_bucket_arn" {
  description = "ARN of the processed S3 bucket"
  value       = aws_s3_bucket.processed_bucket.arn
}

# ============================================================================
# LAMBDA OUTPUTS
# ============================================================================

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.csv_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.csv_processor.arn
}

output "lambda_function_version" {
  description = "Version of the Lambda function"
  value       = aws_lambda_function.csv_processor.version
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

# ============================================================================
# ATHENA OUTPUTS
# ============================================================================

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_glue_catalog_database.csv_processor_db.name
}

output "athena_table_name" {
  description = "Name of the Athena table"
  value       = aws_glue_catalog_table.processed_csv_data.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = var.create_athena_workgroup ? aws_athena_workgroup.csv_processor_workgroup[0].name : "primary"
}

# ============================================================================
# SECURITY OUTPUTS
# ============================================================================

output "kms_key_id" {
  description = "ID of the KMS key used for encryption"
  value       = aws_kms_key.s3_encryption.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_kms_key.s3_encryption.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for encryption"
  value       = aws_kms_alias.s3_encryption_alias.name
}

# ============================================================================
# MONITORING OUTPUTS
# ============================================================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.lambda_dlq.arn
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.lambda_dlq.url
}

# ============================================================================
# NETWORKING OUTPUTS
# ============================================================================

output "lambda_security_group_id" {
  description = "ID of the Lambda security group (if VPC is enabled)"
  value       = var.enable_vpc ? aws_security_group.lambda_sg[0].id : null
}

# ============================================================================
# CONFIGURATION OUTPUTS
# ============================================================================

output "deployment_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# ============================================================================
# QUERY EXAMPLES
# ============================================================================

output "athena_query_examples" {
  description = "Example Athena queries for the processed data"
  value = {
    basic_select = "SELECT * FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name} LIMIT 10;"
    count_records = "SELECT COUNT(*) as total_records FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name};"
    latest_data = "SELECT * FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name} ORDER BY processed_timestamp DESC LIMIT 10;"
    daily_summary = var.enable_athena_partitioning ? "SELECT DATE(processed_timestamp) as date, COUNT(*) as records FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name} GROUP BY DATE(processed_timestamp) ORDER BY date DESC;" : "SELECT COUNT(*) as total_records FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name};"
  }
}

# ============================================================================
# DEPLOYMENT INSTRUCTIONS
# ============================================================================

output "deployment_instructions" {
  description = "Instructions for deploying and using the pipeline"
  value = <<-EOT
    =========================================================================
    S3 CSV Processing Pipeline Deployment Complete!
    =========================================================================
    
    📁 BUCKETS CREATED:
    - Input Bucket: ${aws_s3_bucket.input_bucket.bucket}
    - Processed Bucket: ${aws_s3_bucket.processed_bucket.bucket}
    
    ⚡ LAMBDA FUNCTION:
    - Function Name: ${aws_lambda_function.csv_processor.function_name}
    - Runtime: python3.12
    - Memory: ${var.lambda_memory_size}MB
    - Timeout: ${var.lambda_timeout}s
    
    🔍 ATHENA RESOURCES:
    - Database: ${aws_glue_catalog_database.csv_processor_db.name}
    - Table: ${aws_glue_catalog_table.processed_csv_data.name}
    ${var.create_athena_workgroup ? "- Workgroup: ${aws_athena_workgroup.csv_processor_workgroup[0].name}" : "- Workgroup: primary (default)"}
    
    📊 MONITORING:
    - CloudWatch Logs: ${aws_cloudwatch_log_group.lambda_logs.name}
    - SNS Alerts: ${aws_sns_topic.alerts.arn}
    - Dead Letter Queue: ${aws_sqs_queue.lambda_dlq.name}
    
    🔐 SECURITY:
    - KMS Key: ${aws_kms_key.s3_encryption.arn}
    - Encryption: Enabled on all resources
    - IAM Role: ${aws_iam_role.lambda_exec.name}
    
    📝 USAGE:
    1. Upload CSV files to: s3://${aws_s3_bucket.input_bucket.bucket}/
    2. Lambda will automatically process them
    3. Query processed data in Athena using database: ${aws_glue_catalog_database.csv_processor_db.name}
    
    🔧 MONITORING URLS:
    - Lambda Console: https://${var.aws_region}.console.aws.amazon.com/lambda/home?region=${var.aws_region}#/functions/${aws_lambda_function.csv_processor.function_name}
    - CloudWatch Logs: https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.lambda_logs.name, "/", "$252F")}
    - Athena Console: https://${var.aws_region}.console.aws.amazon.com/athena/home?region=${var.aws_region}#query
    - S3 Console: https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.input_bucket.bucket}
    
    ⚠️  IMPORTANT NOTES:
    - All resources are encrypted with KMS
    - VPC configuration: ${var.enable_vpc ? "Enabled" : "Disabled"}
    - Log retention: ${var.log_retention_days} days
    - Environment: ${var.environment}
    
    =========================================================================
  EOT
}

# ============================================================================
# TERRAFORM STATE OUTPUTS
# ============================================================================

output "terraform_state_info" {
  description = "Information about the Terraform state"
  value = {
    terraform_version = ">= 1.5"
    aws_provider_version = "~> 5.0"
    resources_created = [
      "S3 Buckets (2)",
      "Lambda Function (1)",
      "IAM Role & Policies (3)",
      "KMS Key (1)",
      "CloudWatch Resources (4)",
      "Athena Resources (2)",
      "SNS Topic (1)",
      "SQS Queue (1)",
      var.enable_vpc ? "VPC Security Group (1)" : "VPC Security Group (0)",
      var.create_athena_workgroup ? "Athena Workgroup (1)" : "Athena Workgroup (0)"
    ]
  }
}

# ============================================================================
# COST ESTIMATION
# ============================================================================

output "estimated_monthly_costs" {
  description = "Estimated monthly costs (USD) - actual costs may vary"
  value = {
    lambda = "~$5-20 (depending on executions)"
    s3 = "~$10-50 (depending on storage and requests)"
    athena = "~$5 per TB scanned"
    cloudwatch = "~$2-10 (depending on log volume)"
    kms = "~$1 (key) + $0.03 per 10K requests"
    total_estimate = "~$23-86+ per month (excluding data transfer)"
    note = "Costs vary based on usage patterns, data volume, and query frequency"
  }
}
