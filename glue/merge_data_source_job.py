import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.ml.feature import StopWordsRemover, Tokenizer
from pyspark.sql.functions import col, lit, month, regexp_replace, year, explode

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
output_table_name = "combined_data_v2"
output_s3_uri = "s3://news-data-bucket-assignment1-aloy/output/news_titles"

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
# kaggle_news_df = kaggle_news_df.withColumn("publication_year", year("date"))
# kaggle_news_df = kaggle_news_df.withColumn("publication_month", month("date"))
kaggle_news_df = kaggle_news_df.withColumn("title", col("headline"))
cleaned_kaggle_news_df = kaggle_news_df.select(
    "source_name",
    # "publication_year",
    # "publication_month",
    # "authors",
    "title",
)

news_df = news_df.withColumn("publication_year", year("publishedat"))
news_df = news_df.withColumn("publication_month", month("publishedat"))
news_df = news_df.withColumn("authors", col("author"))

cleaned_news_df = news_df.select(
    "source_name",
    # "publication_year",
    # "publication_month",
    # "authors",
    "title",
)

# Union the two dataframes
combined_df = cleaned_news_df.union(cleaned_kaggle_news_df)
combined_df = combined_df.repartition(1)

# clean "title" column
combined_df = combined_df.select(
    [regexp_replace(col, r",|\.|&|'|\"|\(|\)|:|\?|1|2|3|4|5|6|7|8|9|0|\\|\||-|_", "").alias(col) for col in combined_df.columns]
)
# Tokenize the "title" column
tokenizer = Tokenizer(inputCol="title", outputCol="title_tokens")
tokenized_news_df = tokenizer.transform(combined_df)

# Remove stopwords
remover = StopWordsRemover(inputCol="title_tokens", outputCol="cleaned_title_tokens")
cleaned_news_df = remover.transform(tokenized_news_df)


cleaned_news_df = cleaned_news_df.select(
    "source_name",
    # "publication_year",
    # "publication_month",
    # "authors",
    explode("cleaned_title_tokens").alias("cleaned_title_tokens")
)


# convert back to dynamic frame
combined_data_dynamic_frame_write = DynamicFrame.fromDF(
    cleaned_news_df, glueContext, "combined_data_dynamic_frame_write"
)
glueContext.write_dynamic_frame.from_options(
    frame=combined_data_dynamic_frame_write,
    connection_type="s3",
    connection_options={"path": output_s3_uri},
    format="csv",  # Specify the format as csv
)

job.commit()
