# retrieve variables from terraform.tfvars
variable "AWS_ACCESS_KEY_ID" {
  type = string
}
variable "AWS_SECRET_ACCESS_KEY" {
  type = string
}
variable "NEWS_API_KEY" {
  type = string
}
variable "AWS_ACCOUNT_ID" {
  type = string
}
variable "AWS_REGION" {
  type = string
}

# set default values for variables
variable "news_data_bucket_name" {
  type    = string
  default = "news-data-bucket-assignment1-aloy"
}
variable "news_database" {
  type    = string
  default = "news_database"
}
variable "lambda_bucket_name" {
  type    = string
  default = "lambda-bucket-assignment1-aloy"
}
variable "glue_scripts_bucket_name" {
  type    = string
  default = "glue-scripts-bucket-assignment1-aloy"
}
variable "athena_workgroup_name" {
  type    = string
  default = "athena-workgroup-assignment1-aloy"
}
variable "quicksight_data_source_name" {
  type    = string
  default = "quicksight-data-source-assignment1-aloy"
}
variable "articles_by_agencies_table_name" {
  type    = string
  default = "articles_by_agencies"
}