# ============================================================================
# VARIABLES.TF - Enhanced Variable Definitions
# ============================================================================

# ============================================================================
# CORE CONFIGURATION
# ============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "s3-csv-pipeline"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# ============================================================================
# LAMBDA CONFIGURATION
# ============================================================================

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.lambda_timeout >= 30 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 30 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package"
  type        = string
  default     = "../lambda/lambda.zip"
}

variable "log_level" {
  description = "Lambda function log level"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

# ============================================================================
# S3 CONFIGURATION
# ============================================================================

variable "input_bucket_name" {
  description = "Base name for input bucket (will be prefixed with project-environment)"
  type        = string
  default     = "input"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.input_bucket_name))
    error_message = "Bucket name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "processed_bucket_name" {
  description = "Base name for processed bucket (will be prefixed with project-environment)"
  type        = string
  default     = "processed"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.processed_bucket_name))
    error_message = "Bucket name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "force_destroy_buckets" {
  description = "Allow Terraform to destroy buckets with objects (use with caution)"
  type        = bool
  default     = false
}

# ============================================================================
# SECURITY & ENCRYPTION
# ============================================================================

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

# ============================================================================
# NETWORKING (VPC)
# ============================================================================

variable "enable_vpc" {
  description = "Enable VPC configuration for Lambda"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for Lambda deployment (required if enable_vpc is true)"
  type        = string
  default     = ""
}

variable "lambda_subnet_ids" {
  description = "List of subnet IDs for Lambda deployment (required if enable_vpc is true)"
  type        = list(string)
  default     = []
}

# ============================================================================
# MONITORING & ALERTING
# ============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "alert_email" {
  description = "Email address for alerts (leave empty to disable email notifications)"
  type        = string
  default     = ""
  
  validation {
    condition = var.alert_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address or empty string."
  }
}

variable "error_threshold" {
  description = "Number of Lambda errors before triggering alarm"
  type        = number
  default     = 5
  
  validation {
    condition     = var.error_threshold > 0
    error_message = "Error threshold must be greater than 0."
  }
}

# ============================================================================
# ATHENA CONFIGURATION
# ============================================================================

variable "table_columns" {
  description = "List of columns for Athena table"
  type = list(object({
    name = string
    type = string
  }))
  default = [
    {
      name = "id"
      type = "string"
    },
    {
      name = "name"
      type = "string"
    },
    {
      name = "value"
      type = "double"
    },
    {
      name = "timestamp"
      type = "string"
    },
    {
      name = "processed_timestamp"
      type = "string"
    }
  ]
}

variable "enable_athena_partitioning" {
  description = "Enable Athena table partitioning for better query performance"
  type        = bool
  default     = true
}

variable "create_athena_workgroup" {
  description = "Create a dedicated Athena workgroup"
  type        = bool
  default     = true
}

# ============================================================================
# TAGGING & METADATA
# ============================================================================

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  default     = "devops@company.com"
  
  validation {
    condition = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner_email))
    error_message = "Owner email must be a valid email address."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "backup_required" {
  description = "Whether backup is required for this resource"
  type        = bool
  default     = true
}

variable "compliance_level" {
  description = "Compliance level (none, basic, strict)"
  type        = string
  default     = "basic"
  
  validation {
    condition     = contains(["none", "basic", "strict"], var.compliance_level)
    error_message = "Compliance level must be one of: none, basic, strict."
  }
}

variable "repository_url" {
  description = "URL of the source code repository"
  type        = string
  default     = "https://github.com/company/s3-csv-pipeline"
}
