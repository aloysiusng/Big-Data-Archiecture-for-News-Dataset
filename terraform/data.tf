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
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.news_data_bucket_is459.arn}/input/*", "${aws_s3_bucket.news_data_bucket_is459.arn}/output/*"]
  }
}


data "aws_iam_policy_document" "glue_policy" {
  statement {
    actions = ["glue:*"]
    resources = [
      "${aws_s3_bucket.news_data_bucket_is459.arn}/input/*",
      "${aws_s3_bucket.news_data_bucket_is459.arn}/output/*",
      aws_glue_catalog_database.news_database.arn,
      aws_cloudwatch_log_group.glue_job_log_group.arn,
      "arn:aws:glue:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:table/${var.news_database}/*}",
      "arn:aws:glue:${var.AWS_REGION}:${var.AWS_ACCOUNT_ID}:catalog"
    ]
  }
}

data "local_file" "glue_job_file" {
  filename = "../glue/glue_job.py"
}


data "local_file" "news_dataset" {
  filename = "../data/News_Category_Dataset_v3.json"
}


