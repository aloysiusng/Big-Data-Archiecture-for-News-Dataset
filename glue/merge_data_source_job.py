import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import count, desc, lit, month, year

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

# Initialize contexts and session
glueContext = GlueContext(SparkContext.getOrCreate())
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

news_database = "news_database"
kaggle_tbl = "news_category_dataset_v3_json"
news_tbl = "news_data_json"
output_table_name = "combined_news_table_v2"
output_s3_uri = "s3://news-data-bucket-assignment1-aloy/output/articles_by_agencies"

# Create dynamic frames from the Glue tables
kaggle_news_data = glueContext.create_dynamic_frame.from_catalog(
    database=news_database, table_name=kaggle_tbl
)
news_data = glueContext.create_dynamic_frame.from_catalog(
    database=news_database, table_name=news_tbl
)

kaggle_news_df = kaggle_news_data.toDF()
news_df = news_data.toDF()

# Select only the columns we need
kaggle_news_df = kaggle_news_df.withColumn("source_name", lit("HuffPost"))
kaggle_news_df = kaggle_news_df.withColumn("publication_year", year("date"))
kaggle_news_df = kaggle_news_df.withColumn("publication_month", month("date"))
kaggle_news_df = kaggle_news_df.withColumn("title", "headline")
kaggle_news_df = kaggle_news_df.withColumn("description", "short_description")
cleaned_kaggle_news_df = kaggle_news_df.select(
    "source_name",
    "publication_year",
    "publication_month",
    "authors",
    "title",
    "description",
)

news_df = news_df.withColumn("publication_year", year("publishedat"))
kaggle_news_df = kaggle_news_df.withColumn("publication_month", month("publishedat"))

news_df = news_df.withColumn("authors", "author")

cleaned_news_df = news_df.select(
    "source_name",
    "publication_year",
    "publication_month",
    "authors",
    "title",
    "description",
)

# Union the two dataframes
combined_df = cleaned_news_df.union(cleaned_kaggle_news_df)

combined_df = combined_df.repartition(1)

# convert back to dynamic frame
combined_data_dynamic_frame_write = DynamicFrame.fromDF(
    combined_df, glueContext, "combined_data_dynamic_frame_write"
)

glueContext.write_dynamic_frame.from_catalog(
    frame=combined_data_dynamic_frame_write,
    database=news_database,
    table_name=output_table_name,
    format="parquet",  # Specify the format as Parquet
)

job.commit()
