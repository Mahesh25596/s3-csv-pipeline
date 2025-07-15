import boto3
import os
from transform import process_csv

s3 = boto3.client('s3')
athena = boto3.client('athena')

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        if not key.lower().endswith('.csv'):
            print(f"Skipping non-CSV file: {key}")
            continue
            
        print(f"Processing file: {key} from bucket: {bucket}")
        
        output_bucket = os.environ['PROCESSED_BUCKET']
        output_key = f"processed/{key.replace('.csv', '')}_processed.csv"
        
        process_csv(bucket, key, output_bucket, output_key)
        refresh_athena_table()
        
    return {'statusCode': 200}

def refresh_athena_table():
    query = f"MSCK REPAIR TABLE {os.environ['ATHENA_TABLE']};"
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={'Database': os.environ['ATHENA_DATABASE']},
        ResultConfiguration={
            'OutputLocation': f"s3://{os.environ['PROCESSED_BUCKET']}/athena_results/"
        }
    )
    print(f"Athena table refresh initiated: {response['QueryExecutionId']}")