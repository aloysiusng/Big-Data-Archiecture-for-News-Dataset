import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import ApplyMapping
from pyspark.context import SparkContext
from pyspark.sql import SparkSession

# Initialize the Spark session
sc = SparkContext()
spark = SparkSession(sc)
glueContext = GlueContext(sc)

# Create a Job
job = Job(glueContext)
job.init(sys.argv[0], args=sys.argv[1:])

# Define the Glue database and table names
db_name = "news_database"
table1_name = "news_category_dataset_v3_json"
table2_name = "news_data_json"
merged_table_name = "news_table"

# Create DynamicFrames for the two source tables
df1 = glueContext.create_dynamic_frame.from_catalog(
    database=db_name, table_name=table1_name
)
df2 = glueContext.create_dynamic_frame.from_catalog(
    database=db_name, table_name=table2_name
)

# Apply mapping to add a "source" field to each DynamicFrame
mapping = [
    ("category", "string", "category", "string"),
    ("headline", "string", "headline", "string"),
    ("authors", "string", "authors", "string"),
    ("link", "string", "link", "string"),
    ("short_description", "string", "short_description", "string"),
    ("date", "string", "date", "string"),
    ("source_id", "string", "source_id", "string"),
    ("source_name", "string", "source_name", "string"),
    ("author", "string", "author", "string"),
    ("title", "string", "title", "string"),
    ("description", "string", "description", "string"),
    ("url", "string", "url", "string"),
    ("urltoimage", "string", "urltoimage", "string"),
    ("publishedat", "string", "publishedat", "string"),
    (lambda x: "category", "string", "source", "string")
    (lambda x: "data", "string", "source", "string")
]

df1 = ApplyMapping.apply(frame=df1, mappings=mapping)
df2 = ApplyMapping.apply(frame=df2, mappings=mapping)

# Merge the DynamicFrames
merged_df = df1.union(df2)

# Write the merged DynamicFrame to a new Glue table
glueContext.write_dynamic_frame.from_catalog(
    frame=merged_df, database=db_name, table_name=merged_table_name
)

# Write the merged DynamicFrame to an S3 location
output_s3_uri = "s3://news-data-bucket-assignment1-aloy/output/"
glueContext.write_dynamic_frame.from_catalog(
    frame=merged_df, database=db_name, table_name=output_s3_uri, format="parquet"
)

# Commit the job
job.commit()
