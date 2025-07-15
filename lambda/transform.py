import csv
import boto3
from io import StringIO
from datetime import datetime

s3 = boto3.client('s3')

def process_csv(input_bucket, input_key, output_bucket, output_key):
    # Get the file from S3
    response = s3.get_object(Bucket=input_bucket, Key=input_key)
    csv_content = response['Body'].read().decode('utf-8')
    
    # Process the CSV
    input_lines = csv_content.splitlines()
    reader = csv.reader(input_lines)
    header = next(reader)
    header.append('processed_timestamp')  # Add new column
    
    output_lines = []
    output_lines.append(','.join(header))
    
    for row in reader:
        # Example transformation: lowercase all string fields
        transformed_row = [field.lower() if isinstance(field, str) else field for field in row]
        transformed_row.append(datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        output_lines.append(','.join(transformed_row))
    
    # Write back to S3
    processed_content = '\n'.join(output_lines)
    s3.put_object(
        Bucket=output_bucket,
        Key=output_key,
        Body=processed_content.encode('utf-8')
    )
    
    print(f"Processed file saved to s3://{output_bucket}/{output_key}")