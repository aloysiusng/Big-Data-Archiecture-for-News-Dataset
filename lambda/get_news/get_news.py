import json
import os

import boto3
import requests


def lambda_handler(event, context):
    # Retrieve AWS S3 and News API credentials from environment variables
    s3_bucket_name = os.environ.get("S3_BUCKET_NAME")
    news_api_key = os.environ.get("NEWS_API_KEY")

    if not (s3_bucket_name and news_api_key):
        print("One or more environment variables are missing.")
        return

    # Set up S3 client
    s3 = boto3.client("s3")

    # Call the News API
    news_api_url = "https://newsapi.org/v2/top-headlines"
    params = {"apiKey": news_api_key, "country": "us"}  # Adjust this as needed

    response = requests.get(news_api_url, params=params)

    if response.status_code == 200:
        news_data = response.json()

        # Store the News API data in S3
        s3_object_key = "news_data.json"  # Adjust the object key as needed
        s3.put_object(
            Bucket=s3_bucket_name,
            Key=s3_object_key,
            Body=json.dumps(news_data),
            ContentType="application/json",
        )
        print(f"News data stored in S3: s3://{s3_bucket_name}/{s3_object_key}")
    else:
        print(
            f"Failed to fetch news data from News API. Status code: {response.status_code}"
        )

