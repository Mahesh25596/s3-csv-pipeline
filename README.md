S3 CSV PROCESSING PIPELINE
=========================

Description:
------------
This project automates the processing of CSV files uploaded to an S3 bucket. It includes:
1. Lambda function triggered by new CSV uploads
2. CSV transformation and processing
3. Storage in processed S3 bucket
4. Athena integration for querying processed data

Prerequisites:
-------------
1. AWS account with appropriate permissions
2. AWS CLI installed and configured
3. Terraform installed
4. Python 3.x
5. pip package manager

Project Structure:
-----------------
```bash
s3-csv-pipeline/
├── lambda/                   # Lambda function code
│   ├── main.py               # Lambda handler
│   ├── requirements.txt      # Python dependencies
│   └── transform.py          # CSV transformation logic
├── terraform/                # Terraform infrastructure
│   ├── main.tf               # Main Terraform config
│   ├── variables.tf          # Variable definitions
│   └── outputs.tf           # Output values
├── setup.sh                  # Automated deployment script
└── README.txt               # This file
```

Setup Instructions:
------------------
1. Clone this repository
2. Configure AWS credentials:
```bash
   aws configure
```
3. Make setup.sh executable:
```bash
   chmod +x setup.sh
```
4. Run the setup script:
```bash
   ./setup.sh
```
The script will:
- Install Python dependencies
- Package the Lambda function
- Deploy infrastructure using Terraform

Manual Deployment (alternative):
-------------------------------
1. Prepare Lambda package:
```bash
   cd lambda
   pip install -r requirements.txt -t .
   find . -type d -name "__pycache__" -exec rm -rf {} +
   find . -type d -name "tests" -exec rm -rf {} +
   find . -name "*.so" -exec rm -rf {} +
   find . -name "*.pyc" -exec rm -rf {} +
   zip -r ../lambda/lambda.zip .
   cd ..
```
2. Deploy infrastructure:
```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   cd ..
```

How It Works:
------------
1. Upload a CSV file to the input S3 bucket
2. Lambda function is automatically triggered
3. CSV is processed (transformations applied)
4. Processed data is saved to output bucket
5. Athena table is updated for querying

Querying Data:
-------------
Use Athena to query processed data:
```bash
SELECT * FROM <athena_database>.<athena_table> LIMIT 10;
```
Output values will be displayed after deployment.


Cleanup:
-------
To destroy all resources:
```bash
cd terraform
terraform destroy
```
Notes:
------
1. S3 bucket names must be globally unique
2. Default region is eu-central-1 (change in variables.tf if needed)
3. First-time Athena setup may take a few minutes

Support:
--------
For issues, please contact: https://www.linkedin.com/in/smk25/



