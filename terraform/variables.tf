variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "s3-csv-pipeline"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "input_bucket_name" {
  description = "Base name for input bucket"
  type        = string
  default     = "input"
}

variable "processed_bucket_name" {
  description = "Base name for processed bucket"
  type        = string
  default     = "processed"
}