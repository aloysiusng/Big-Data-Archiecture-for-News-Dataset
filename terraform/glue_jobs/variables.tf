variable "job_name" {
  type = string
  //merge_data_source_job
}

variable "script_location" {
  type = string
  # data.local_file.articles_by_agencies_etl_job_py_file.filename
}

variable "s3_bucket_id" {
  type = string
  //aws_s3_bucket.glue_scripts_bucket.id
}

variable "iam_role_arn" {
  type = string
  //aws_iam_role.glue_role.arn
}