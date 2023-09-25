import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ["JOB_NAME"])

glueContext = GlueContext(SparkContext.getOrCreate())
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

news_database = "news_database"

# Create dynamic frames from the Glue tables
news_category = glueContext.create_dynamic_frame.from_catalog(
    database=news_database, table_name="news_category_dataset_v3_json"
)
news_data = glueContext.create_dynamic_frame.from_catalog(
    database=news_database, table_name="news_data_json"
)

# Apply transformations to extract the year from the date
news_category = news_category.apply_mapping(
    [("date", "string", "publication_year", "int")], transformation_ctx="map"
)
news_data = news_data.apply_mapping(
    [("publishedat", "string", "publication_year", "int")], transformation_ctx="map"
)

# Union the two dataframes
combined_data = news_category.union(news_data)

# Group and aggregate the data
agg_data = combined_data.groupBy(["source_name", "publication_year"]).agg(
    count=Count().field("source_name")
)

# Write the aggregated data to a new Glue table
glueContext.write_dynamic_frame.from_catalog(
    frame=agg_data, database=news_database, table_name="articles_by_agencies"
)

output_s3_uri = "s3://news-data-bucket-assignment1-aloy/output/articles_by_agencies"
glueContext.write_dynamic_frame.from_catalog(
    frame=agg_data, database=news_database, table_name=output_s3_uri, format="parquet"
)

job.commit()
