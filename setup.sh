#!/bin/bash

# Exit immediately if any command fails
set -e

echo "Starting deployment process..."

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is not installed. Please install it first."
    exit 1
fi

# Check pip version
if ! command -v pip3 &> /dev/null; then
    echo "pip3 is not installed. Please install it first."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "Terraform is not installed. Please install it first."
    exit 1
fi

# Get current directory
ROOT_DIR=$(pwd)

# Lambda preparation
echo "Preparing Lambda function..."
cd "$ROOT_DIR/lambda"

# Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt -t .

# Clean up unnecessary files
echo "Cleaning up temporary files..."
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -type d -name "tests" -exec rm -rf {} +
find . -name "*.so" -exec rm -rf {} +
find . -name "*.pyc" -exec rm -rf {} +
find . -name "*.dist-info" -exec rm -rf {} +

# Create deployment package
echo "Creating Lambda deployment package..."
zip -r ../lambda/lambda.zip . > /dev/null

# Return to root directory
cd "$ROOT_DIR"

# Terraform deployment
echo "Starting Terraform deployment..."
cd "$ROOT_DIR/terraform"

# Initialize Terraform
echo "Running terraform init..."
terraform init

# Plan deployment
echo "Running terraform plan..."
terraform plan

# Apply changes
echo "Running terraform apply..."
terraform apply -auto-approve

# Get outputs
echo "Deployment complete! Here are your outputs:"
terraform output

echo "Setup completed successfully!"