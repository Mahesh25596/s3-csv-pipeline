import csv
import boto3
from io import StringIO
from datetime import datetime

s3 = boto3.client('s3')

def process_csv(input_bucket, input_key, output_bucket, output_key):
    # Get the file from S3
    response = s3.get_object(Bucket=input_bucket, Key=input_key)
    csv_content = response['Body'].read().decode('utf-8-sig')  # Use utf-8-sig to strip BOM
    
    # Process CSV
    input_lines = csv_content.splitlines()
    reader = csv.reader(input_lines)
    header = next(reader)
    
    # Ensure headers are clean (remove special chars, lowercase)
    processed_header = [h.strip().lower().replace(' ', '_') for h in header]
    processed_header.append('processed_timestamp')
    
    # Write output with proper CSV formatting
    output = StringIO()
    writer = csv.writer(output, quoting=csv.QUOTE_MINIMAL)
    writer.writerow(processed_header)
    
    for row in reader:
        transformed_row = [
            field.strip().lower() if isinstance(field, str) else field 
            for field in row
        ]
        transformed_row.append(datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        writer.writerow(transformed_row)
    
    # Upload to S3
    s3.put_object(
        Bucket=output_bucket,
        Key=output_key,
        Body=output.getvalue().encode('utf-8')
    )
    
    print(f"Processed file saved to s3://{output_bucket}/{output_key}")