# S3====================================================================================================
resource "aws_s3_bucket" "news_data_bucket_is459" {
  bucket = var.news_data_bucket_name
}
resource "aws_s3_object" "input" {
  bucket                 = aws_s3_bucket.news_data_bucket_is459.id
  key                    = "input/"
  content_type           = "application/x-directory"
  server_side_encryption = "AES256"
}
resource "aws_s3_object" "output" {
  bucket                 = aws_s3_bucket.news_data_bucket_is459.id
  key                    = "output/"
  content_type           = "application/x-directory"
  server_side_encryption = "AES256"
}
# place kaggle data inside input
resource "aws_s3_object" "news_dataset_object" {
  bucket                 = aws_s3_bucket.glue_scripts_bucket.id
  key                    = "News_Category_Dataset_v3.json"
  source                 = data.local_file.news_dataset.filename
  content_type           = "application/json"
  server_side_encryption = "AES256"
}
# lambda bucket
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.lambda_bucket_name
}
# glue script bucket
resource "aws_s3_bucket" "glue_scripts_bucket" {
  bucket = var.glue_scripts_bucket_name
}

# Lambda====================================================================================================
# lambda iam
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_assume_role_policy.json
}
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "lambda-s3-access-policy"
  description = "Policy for lambda to access S3"
  policy      = data.aws_iam_policy_document.lambda_s3_policy.json
}
resource "aws_iam_policy_attachment" "lambda_s3_attachment" {
  name       = "lambda-s3-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}
resource "aws_iam_policy" "cloudwatch_access" {
  name        = "cloudwatch-access-policy"
  description = "Policy for cloudwatch access"
  policy      = data.aws_iam_policy_document.cloudwatch_policy.json
}

resource "aws_iam_policy_attachment" "cloudwatch_attachment" {
  name       = "cloudwatch-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.cloudwatch_access.arn
}

resource "aws_iam_policy" "lambda_access" {
  name        = "lambda-access-policy"
  description = "Policy for lambda access"
  policy      = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_policy_attachment" "lambda_attachment" {
  name       = "lambda-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.lambda_access.arn
}

# lambda codebase
resource "aws_lambda_function" "get_news_api" {
  function_name = "news_api_lambda"
  filename      = "../lambda/get_news.zip"
  role          = aws_iam_role.lambda_role.arn
  handler       = "get_news.get_news.lambda_handler"

  # source_code_hash = filebase64sha256("../lambda/get_news.zip")
  source_code_hash = data.archive_file.get_news_zip.output_base64sha256

  runtime = "python3.8"
  timeout = 900

  environment {
    variables = {
      S3_BUCKET_NAME = var.news_data_bucket_name
      NEWS_API_KEY   = var.NEWS_API_KEY
    }
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
# glue iam
resource "aws_iam_role" "glue_role" {
  name               = "glue_role"
  assume_role_policy = data.aws_iam_policy_document.glue_role_assume_role_policy.json
}
resource "aws_iam_policy" "glue_s3_access" {
  name        = "glue-s3-access-policy"
  description = "Policy for glue to access S3"
  policy      = data.aws_iam_policy_document.glue_s3_policy.json
}
resource "aws_iam_policy_attachment" "glue_s3_attachment" {
  name       = "glue-s3-attachment"
  roles      = [aws_iam_role.glue_role.name]
  policy_arn = aws_iam_policy.glue_s3_access.arn
}
resource "aws_iam_policy" "glue_access" {
  name        = "glue-access-policy"
  description = "Policy for glue to access S3"
  policy      = data.aws_iam_policy_document.glue_policy.json
}
resource "aws_iam_policy_attachment" "glue_attachment" {
  name       = "glue-attachment"
  roles      = [aws_iam_role.glue_role.name]
  policy_arn = aws_iam_policy.glue_access.arn
}
# glue crawler
resource "aws_glue_crawler" "news_data_crawler" {
  name          = "news_data_crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.news_database.name

  s3_target {
    path = "s3://${aws_s3_bucket.news_data_bucket_is459.id}/input/"
  }

}
resource "aws_glue_catalog_table" "news_table" {
  name          = "news_table"
  database_name = aws_glue_catalog_database.news_database.name
}

# glue job (TODO: need to change the script location)
resource "aws_cloudwatch_log_group" "glue_job_log_group" {
  name              = "glue_job_log_group"
  retention_in_days = 14
}
# add glue job script to s3 -
resource "aws_s3_object" "glue_script_object" {
  bucket                 = aws_s3_bucket.glue_scripts_bucket.id
  key                    = "glue_job.py"
  source                 = data.local_file.glue_job_file.filename
  content_type           = "text/x-python"
  server_side_encryption = "AES256"
}
resource "aws_glue_job" "glue_etl_job" {
  name     = "glue-etl-job"
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.glue_scripts_bucket.id}/glue_job.py"
  }
  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_job_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
  }
}



# resource "aws_quicksight_data_source" "my_data_source" {
#   name = "my-data-source"
#   type = "ATHENA"
#   athena_parameters {
#     work_group = "my-athena-workgroup"
#   }
# }

# resource "aws_quicksight_dataset" "my_dataset" {
#   name        = "my-dataset"
#   data_source = aws_quicksight_data_source.my_data_source.arn

#   # Define dataset schema and fields
# }

# resource "aws_quicksight_analysis" "my_analysis" {
#   name        = "my-analysis"
#   theme_arn   = aws_quicksight_theme.my_theme.arn
#   data_source = aws_quicksight_data_source.my_data_source.arn

#   # Define analysis structure
# }

# resource "aws_quicksight_dashboard" "my_dashboard" {
#   name        = "my-dashboard"
#   permissions = ["PUBLIC"]
#   source_entity {
#     source_template {
#       arn = aws_quicksight_analysis.my_analysis.arn
#     }
#   }
# }
