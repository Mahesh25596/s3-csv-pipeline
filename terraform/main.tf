provider "aws" {
  region = var.aws_region
}

provider "random" {}

resource "random_id" "bucket_suffix" {
  byte_length = 8
}

locals {
  input_bucket_name    = "csv-input-${random_id.bucket_suffix.hex}"
  processed_bucket_name = "csv-processed-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket" "input_bucket" {
  bucket = local.input_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.csv_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".csv"
  }
}

resource "aws_s3_bucket" "processed_bucket" {
  bucket = local.processed_bucket_name
  force_destroy = true
}





# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_s3_athena_policy"
  description = "Policy for Lambda to access S3 and Athena"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = [
          "${aws_s3_bucket.input_bucket.arn}/*",
          "${aws_s3_bucket.processed_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:UpdateTable"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "csv_processor" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 30
  memory_size      = 128

  filename         = "../lambda/lambda.zip"
  source_code_hash = filebase64sha256("../lambda/lambda.zip")

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed_bucket.id
      ATHENA_DATABASE = var.athena_database_name
      ATHENA_TABLE    = var.athena_table_name
    }
  }
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.csv_processor.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

# Athena Database
resource "aws_glue_catalog_database" "csv_processor_db" {
  name = var.athena_database_name
}

# Athena Table
resource "aws_glue_catalog_table" "processed_csv_data" {
  name          = var.athena_table_name
  database_name = aws_glue_catalog_database.csv_processor_db.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "skip.header.line.count" = "1"
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

    # Dynamically create columns based on the CSV structure
    # This is a basic example - you might want to adjust based on your actual CSV structure
    columns {
      name = "column1"
      type = "string"
    }
    columns {
      name = "column2"
      type = "string"
    }
    columns {
      name = "processed_timestamp"
      type = "string"
    }
  }
}