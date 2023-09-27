import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql.functions import count, desc, lit, year

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
cleaned_kaggle_news_df = kaggle_news_df.select("source_name", "publication_year")

news_df = news_df.withColumn("publication_year", year("publishedat"))
cleaned_news_df = news_df.select("source_name", "publication_year")


# Union the two dataframes
combined_df = cleaned_news_df.union(cleaned_kaggle_news_df)


# Group and aggregate the data
agg_data = combined_df.groupBy("source_name", "publication_year").agg(
    count("*").alias("article_count")
)
agg_data = agg_data.orderBy(desc("publication_year"))
# LOAD (WRITE DATA)
agg_data = agg_data.repartition(2)

# convert back to dynamic frame
agg_data_dynamic_frame_write = DynamicFrame.fromDF(
    agg_data, glueContext, "agg_data_dynamic_frame_write"
)

glueContext.write_dynamic_frame.from_options(
    frame=agg_data_dynamic_frame_write,
    connection_type="s3",
    connection_options={"path": output_s3_uri},
    format="csv",
)


job.commit()
