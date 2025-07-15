variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "input_bucket_name" {
  description = "Name of the S3 bucket for input CSV files"
  default     = "my-unique-csv-input-bucket-12345"  # Change to something unique
}

variable "processed_bucket_name" {
  description = "Name of the S3 bucket for processed data"
  default     = "my-unique-csv-processed-bucket-12345"  # Change to something unique
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  default     = "csv-processor"
}

variable "athena_database_name" {
  description = "Name of the Athena database"
  default     = "csv_processor_db"
}

variable "athena_table_name" {
  description = "Name of the Athena table"
  default     = "processed_csv_data"
}