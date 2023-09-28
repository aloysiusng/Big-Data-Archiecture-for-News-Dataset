# lambda --------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3_policy" {
  statement {
    actions   = ["s3:*", "s3-object-lambda:*"]
    resources = ["${aws_s3_bucket.news_data_bucket_is459.arn}/input/*", "${aws_s3_bucket.news_data_bucket_is459.arn}/output/*"]
  }
}

data "aws_iam_policy_document" "cloudwatch_policy" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}

data "archive_file" "get_news_zip" {
  type        = "zip"
  source_dir  = "../lambda/get_news"
  output_path = "../lambda/get_news.zip"
}

# glue ----------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "glue_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "glue_s3_policy" {
  statement {
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.news_data_bucket_is459.arn, "${aws_s3_bucket.news_data_bucket_is459.arn}/*", aws_s3_bucket.glue_scripts_bucket.arn, "${aws_s3_bucket.glue_scripts_bucket.arn}/*"]
  }
}


data "aws_iam_policy_document" "glue_policy" {
  statement {
    actions = ["glue:*", "athena:*"]
    resources = [
      "${aws_s3_bucket.news_data_bucket_is459.arn}/input/*",
      "${aws_s3_bucket.news_data_bucket_is459.arn}/output/*",
      aws_glue_catalog_database.news_database.arn,
      "arn:aws:logs:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:*",
      "arn:aws:glue:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:table/${var.news_database}/*",
      "arn:aws:glue:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:catalog"
    ]
  }
}

data "local_file" "merge_data_source_job_py_file" {
  filename = "../glue/merge_data_source_job.py"
}

data "local_file" "articles_by_agencies_etl_job_py_file" {
  filename = "../glue/articles_by_agencies_etl_job.py"
}

data "local_file" "news_dataset" {
  filename = "../data/News_Category_Dataset_v3.json"
}


