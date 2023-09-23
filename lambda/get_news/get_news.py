import json
import os

import boto3
import requests

# Constants
NEWS_API_KEY = os.environ.get("NEWS_API_KEY")
S3_BUCKET_NAME = os.environ.get("S3_BUCKET_NAME")
S3_OBJECT_KEY = "news_data.json"
COUNTRY = "us"
PAGE_SIZE = 100
LANGUAGE = "en"
page = 1

HEADERS = {"X-Api-Key": NEWS_API_KEY}
NEWS_API_SOURCES_URL = f"https://newsapi.org/v2/top-headlines/sources"
NEWS_API_EVERYTHING_URL = f"https://newsapi.org/v2/everything"


def get_sources(news_api_sources_url, headers, params):
    sources_response = requests.get(
        news_api_sources_url, headers=headers, params=params
    )

    if sources_response.status_code == 200:
        sources = sources_response.json()["sources"]
        source_ids = [source["id"] for source in sources]
        return {
            "source_id_strings": [
                ",".join(source_ids[i : i + 20]) for i in range(0, len(source_ids), 20)
            ],
            "success": True,
            "message": "Success",
        }
    else:
        return {
            "source_id_strings": None,
            "success": False,
            "message": f"Failed to fetch news data from News API /v2/top-headlines/sources. Status code: {sources_response.status_code}",
        }


def lambda_handler(event, context):
    source_resp = get_sources(
        NEWS_API_SOURCES_URL, HEADERS, params={"country": COUNTRY}
    )
    # if failed to get sources, return error
    if not source_resp["success"]:
        return {"statusCode": 500, "body": source_resp["message"]}

    top_headlines_to_S3 = []
    failed_sources = []
    # <insertion>
    for source_ids in source_resp["source_id_strings"]:
        top_headlines_response = requests.get(
            NEWS_API_EVERYTHING_URL,
            headers=HEADERS,
            params={
                "sources": source_ids,
                "language": LANGUAGE,
                "pageSize": PAGE_SIZE,
                "page": page,
            },
        )
        if top_headlines_response.status_code == 200:
            top_headlines_to_S3.append(top_headlines_response.json()["articles"])
        else:
            failed_sources.append(source_ids)
    # if no news data is fetched, return error 
    if len(top_headlines_to_S3) == 0:
        return {
            "statusCode": 500,
            "body": f"Failed to fetch any news data from News API /v2/everything. Status code: {top_headlines_response.status_code}",
        }

    try:
        s3 = boto3.client("s3")
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=S3_OBJECT_KEY,
            Body=json.dumps(top_headlines_to_S3),
            ContentType="application/json",
        )
        result_message = (
            f"News data stored in S3: s3://{S3_BUCKET_NAME}/{S3_OBJECT_KEY}"
        )
        if failed_sources:
            return {
                "statusCode": 201,
                "body": f"{result_message} with partial failure. Failed sources: {failed_sources}",
                "data": failed_sources,
            }
        return {"statusCode": 200, "body": result_message}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
