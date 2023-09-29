# S3====================================================================================================
resource "aws_s3_bucket" "news_data_bucket_is459" {
  bucket = var.news_data_bucket_name
}
resource "aws_s3_object" "input" {
  bucket = aws_s3_bucket.news_data_bucket_is459.id
  key    = "input/"
}
resource "aws_s3_object" "output" {
  bucket = aws_s3_bucket.news_data_bucket_is459.id
  key    = "output/"
}
# place kaggle data inside input
resource "aws_s3_object" "news_dataset_object" {
  bucket       = aws_s3_bucket.news_data_bucket_is459.id
  key          = "input/${var.kaggle_data_source_name}"
  source       = data.local_file.news_dataset.filename
  content_type = "application/json"
}
# lambda bucket
# resource "aws_s3_bucket" "lambda_bucket" {
#   bucket = var.lambda_bucket_name
# }
# glue script bucket
resource "aws_s3_bucket" "glue_scripts_bucket" {
  bucket = var.glue_scripts_bucket_name
}
# IAM Policies + Roles ====================================================================================================
# Lambda IAM 
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_assume_role_policy.json
}
module "attach_policies_for_lambda" {
  source     = "./iam_policies"
  role_names = [aws_iam_role.lambda_role.name]
  policy_names = [
    "lambda-s3-access-policy",
    "lambda-access-policy",
  ]
  policy_descriptions = [
    "Policy for lambda to access S3",
    "Policy for lambda access",
  ]
  policy_documents = [
    data.aws_iam_policy_document.lambda_s3_policy.json,
    data.aws_iam_policy_document.lambda_policy.json,
  ]
}
# Glue IAM
resource "aws_iam_role" "glue_role" {
  name               = "glue_role"
  assume_role_policy = data.aws_iam_policy_document.glue_role_assume_role_policy.json
}
module "attach_policies_policies" {
  source     = "./iam_policies"
  role_names = [aws_iam_role.glue_role.name]
  policy_names = [
    "glue-access-policy",
    "glue-s3-access-policy",
  ]
  policy_descriptions = [
    "Policy for lambda to access glue",
    "Policy for glue to access S3",
  ]
  policy_documents = [
    data.aws_iam_policy_document.glue_policy.json,
    data.aws_iam_policy_document.glue_s3_policy.json,
  ]
}
resource "aws_iam_policy" "cloudwatch_access_policy" {
  name        = "cloudwatch-access-policy"
  description = "Policy for cloudwatch access"
  policy      = data.aws_iam_policy_document.cloudwatch_policy.json
}

# Attach policies to both roles
resource "aws_iam_policy_attachment" "cloudwatch_access_policy_attachment" {
  name       = "cloudwatch-access-policy-attachment"
  roles      = [aws_iam_role.lambda_role.name, aws_iam_role.glue_role.name]
  policy_arn = aws_iam_policy.cloudwatch_access_policy.arn
}

# Lambda====================================================================================================
# lambda function
resource "aws_lambda_function" "get_news_api" {
  function_name = "get_news"
  filename      = "../lambda/get_news.zip"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"

  # source_code_hash = filebase64sha256("../lambda/get_news.zip")
  source_code_hash = data.archive_file.get_news_zip.output_base64sha256

  runtime = "nodejs14.x"
  timeout = 900

  environment {
    variables = {
      S3_BUCKET_NAME = var.news_data_bucket_name
      NEWS_API_KEY   = var.NEWS_API_KEY
    }
  }
}
resource "aws_lambda_function_url" "test_live" {
  function_name      = aws_lambda_function.get_news_api.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["GET"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
# lambda function logging
resource "aws_cloudwatch_log_group" "get_news" {
  name              = "/aws/lambda/${aws_lambda_function.get_news_api.function_name}"
  retention_in_days = 14
}
# invoke lambda daily
resource "aws_cloudwatch_event_rule" "daily_invoke_rule" {
  name                = "daily_invoke_rule"
  description         = "Rule to schedule Lambda function daily"
  schedule_expression = "cron(0 12 * * ? *)" # Daily at 12:00 PM UTC
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_invoke_rule.name
  target_id = "invoke_get_news_api"
  arn       = aws_lambda_function.get_news_api.arn
}
# Glue====================================================================================================
# glue catalog
resource "aws_glue_catalog_database" "news_database" {
  name = var.news_database

  create_table_default_permission {
    permissions = ["SELECT"]
    principal {
      data_lake_principal_identifier = "IAM_ALLOWED_PRINCIPALS"
    }
  }
}
# glue crawler
resource "aws_glue_crawler" "news_data_crawler" {
  name          = "news_data_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.news_database.name
  schedule      = "cron(20 0 * * ? *)" // Daily at 12:20 AM UTC
  s3_target {
    path = "s3://${aws_s3_bucket.news_data_bucket_is459.id}/input"
  }

}
resource "aws_glue_trigger" "news_data_crawler_on_demand_trigger" {
  name = "news-data-crawler-on-demand-trigger"
  type = "ON_DEMAND"
  actions {
    crawler_name = aws_glue_crawler.news_data_crawler.name
  }
}

resource "aws_glue_catalog_table" "combined_news_table" {
  name          = "combined_news_table"
  database_name = aws_glue_catalog_database.news_database.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL              = "TRUE"
    "parquet.compression" = "SNAPPY"
  }
  storage_descriptor {
    # location      = "s3://news-data-bucket-assignment1-aloy/outputs/articles_by_agencies/"
    location      = "s3://${aws_s3_bucket.news_data_bucket_is459.id}/output/articles_by_agencies/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "combined_news"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"

      parameters = {
        "serialization.format" = 1
      }
    }
    columns {
      name = "source_name"
      type = "string"
    }

    columns {
      name = "publication_year"
      type = "int"
    }

    columns {
      name = "article_count"
      type = "int"
    }
  }
}

# glue jobs for etl ============ **saves to both s3 and glue catalog ========================================================================================
# saves to news_database.articles_by_agencies and to s3://news-data-bucket-assignment1-aloy/output/articles_by_agencies/
module "articles_by_agencies_etl_job" {
  source          = "./glue_jobs"
  job_name        = "articles_by_agencies_etl_job"
  script_location = data.local_file.articles_by_agencies_etl_job_py_file.filename
  s3_bucket_id    = aws_s3_bucket.glue_scripts_bucket.id
  iam_role_arn    = aws_iam_role.glue_role.arn

}

# module "merge_data_source_job" {
#   source          = "./glue_jobs"
#   job_name        = "merge_data_source_job"
#   script_location = data.local_file.merge_data_source_job_py_file.filename
#   s3_bucket_id    = aws_s3_bucket.glue_scripts_bucket.id
#   iam_role_arn    = aws_iam_role.glue_role.arn
# }

# Athena====================================================================================================
resource "aws_athena_workgroup" "articles_by_agencies_athena_workgroup" {
  name = "${var.articles_by_agencies_table_name}_athena_workgroup"
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.news_data_bucket_is459.bucket}/athena/output/${var.articles_by_agencies_table_name}/"
    }
  }
}
resource "aws_athena_workgroup" "huff_post_articles_nathena_workgroup" {
  name = "${var.huff_post_articles_table_name}_athena_workgroup"
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.news_data_bucket_is459.bucket}/athena/output/${var.huff_post_articles_table_name}/"
    }
  }
}
resource "aws_athena_workgroup" "category_wordcloud_nathena_workgroup" {
  name = "category_wordcloud_athena_workgroup"
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.news_data_bucket_is459.bucket}/athena/output/category_wordcloud/"
    }
  }
}

# athena query for articles by agencies  ->  ETL job already settled the aggregation
resource "aws_athena_named_query" "articles_by_agencies_query" {
  name      = "articles_by_agencies_query"
  workgroup = aws_athena_workgroup.articles_by_agencies_athena_workgroup.id
  database  = aws_glue_catalog_database.news_database.name
  query     = "SELECT * FROM combined_news_table;"
}
