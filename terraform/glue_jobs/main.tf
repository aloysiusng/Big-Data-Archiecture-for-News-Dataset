resource "aws_cloudwatch_log_group" "glue_job_log_group" {
  name              = "${var.job_name}_log_group"
  retention_in_days = 14
}
# add glue job script to s3 -
resource "aws_s3_object" "s3_merge_data_source_job" {
  bucket                 = var.s3_bucket_id
  key                    = "${var.job_name}.py"
  source                 = var.script_location
  content_type           = "text/x-python"
  server_side_encryption = "AES256"
}
resource "aws_glue_job" "merge_data_source_job" {
  name     = var.job_name
  role_arn = var.iam_role_arn
  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${var.s3_bucket_id}/${var.job_name}.py"
  }
  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_job_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = ""
  }
}
resource "aws_glue_trigger" "news_data_etl_on_demand_trigger" {
  name = "${var.job_name}-on-demand-trigger"
  type = "ON_DEMAND"
  actions {
    job_name = aws_glue_job.merge_data_source_job.name
  }
}
resource "aws_glue_trigger" "news_data_etl_scheduled_trigger" {
  name     = "${var.job_name}-scheduled-trigger"
  type     = "SCHEDULED"
  schedule = "cron(40 0 * * ? *)" // Daily at 12:30 AM UTC
  actions {
    job_name = aws_glue_job.merge_data_source_job.name
  }
}