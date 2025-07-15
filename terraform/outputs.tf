output "input_bucket_name" {
  description = "Name of the input S3 bucket"
  value       = aws_s3_bucket.input_bucket.bucket
}

output "processed_bucket_name" {
  description = "Name of the processed S3 bucket"
  value       = aws_s3_bucket.processed_bucket.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.csv_processor.function_name
}

output "athena_database_name" {
  description = "Name of the Athena database"
  value       = aws_glue_catalog_database.csv_processor_db.name
}

output "athena_table_name" {
  description = "Name of the Athena table"
  value       = aws_glue_catalog_table.processed_csv_data.name
}

output "query_example" {
  description = "Example Athena query"
  value       = <<EOT
You can query your processed data with Athena using:
SELECT * FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name} LIMIT 10;
EOT
}