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

# set default values for variables
variable "news_data_bucket_is459" {
  type    = string
  default = "news_data_bucket_is459"
}
variable "news_database" {
  type    = string
  default = "news_database"
}
variable "lambda_bucket_name" {
  type    = string
  default = "lambda_bucket"
}
variable "glue_scripts_bucket_name" {
  type    = string
  default = "glue_scripts_bucket"
}