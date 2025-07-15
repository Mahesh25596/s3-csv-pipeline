output "input_bucket_name" {
  value = aws_s3_bucket.input_bucket.id
}

output "processed_bucket_name" {
  value = aws_s3_bucket.processed_bucket.id
}

output "lambda_function_name" {
  value = aws_lambda_function.csv_processor.function_name
}

output "athena_database_name" {
  value = aws_glue_catalog_database.csv_processor_db.name
}

output "athena_table_name" {
  value = aws_glue_catalog_table.processed_csv_data.name
}

output "query_example" {
  value = <<EOT
You can query your processed data with Athena using:
SELECT * FROM ${aws_glue_catalog_database.csv_processor_db.name}.${aws_glue_catalog_table.processed_csv_data.name} LIMIT 10;
EOT
}