const axios = require("axios");
const AWS = require("aws-sdk");

const NEWS_API_KEY = process.env.NEWS_API_KEY;
const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME;
const S3_OBJECT_KEY = "news_data.json";
const COUNTRY = "us";
const PAGE_SIZE = 100;
const LANGUAGE = "en";
let page = 1;

const NEWS_API_SOURCES_URL = "https://newsapi.org/v2/top-headlines/sources";
const NEWS_API_EVERYTHING_URL = "https://newsapi.org/v2/everything";

const HEADERS = {
  "X-Api-Key": NEWS_API_KEY,
};

const s3 = new AWS.S3();

const getSources = async (newsApiSourcesUrl, headers, params) => {
  try {
    const response = await axios.get(newsApiSourcesUrl, {
      headers,
      params,
    });

    if (response.status === 200) {
      const sources = response.data.sources;
      const sourceIds = sources.map((source) => source.id);
      const sourceIdStrings = [];

      for (let i = 0; i < sourceIds.length; i += 20) {
        sourceIdStrings.push(sourceIds.slice(i, i + 20).join(","));
      }

      return {
        sourceIdStrings,
        success: true,
        message: "Success",
      };
    } else {
      return {
        sourceIdStrings: null,
        success: false,
        message: `Failed to fetch news data from News API /v2/top-headlines/sources. Status code: ${response.status}`,
      };
    }
  } catch (error) {
    return {
      sourceIdStrings: null,
      success: false,
      message: `Error: ${error.message}`,
    };
  }
};

exports.handler = async (event, context) => {
  const sourceResp = await getSources(NEWS_API_SOURCES_URL, HEADERS, { country: COUNTRY });

  if (!sourceResp.success) {
    return {
      statusCode: 500,
      body: sourceResp.message,
    };
  }

  const topHeadlinesToS3 = [];
  const failedSources = [];

  for (const sourceIds of sourceResp.sourceIdStrings) {
    try {
      const topHeadlinesResponse = await axios.get(NEWS_API_EVERYTHING_URL, {
        headers: HEADERS,
        params: {
          sources: sourceIds,
          language: LANGUAGE,
          pageSize: PAGE_SIZE,
          page,
        },
      });

      if (topHeadlinesResponse.status === 200) {
        topHeadlinesToS3.push(topHeadlinesResponse.data.articles);
      } else {
        failedSources.push(sourceIds);
      }
    } catch (error) {
      failedSources.push(sourceIds);
    }
  }

  if (topHeadlinesToS3.length === 0) {
    return {
      statusCode: 500,
      body: `Failed to fetch any news data from News API /v2/everything. Status code: ${topHeadlinesResponse.status}`,
    };
  }
  // pre-process topHeadlinesToS3
  var topHeadlinesToS3String = "";

  // Iterate through the array and transform each article
  topHeadlinesToS3.forEach((articleGroup) => {
    articleGroup.forEach((article) => {
      // Create a new object for the transformed article
      const flattenedArticle = {
        source_id: article.source.id,
        source_name: article.source.name,
        author: article.author,
        title: article.title,
        description: article.description,
        url: article.url,
        urlToImage: article.urlToImage,
        publishedAt: article.publishedAt,
        content: article.content,
      };

      // Push the transformed article to the array
      topHeadlinesToS3String += JSON.stringify(flattenedArticle);
    });
  });

  let s3PutResponse;
  try {
    s3PutResponse = await s3
      .putObject({
        Bucket: "news-data-bucket-assignment1-aloy/input",
        Key: "news_data.json",
        Body: topHeadlinesToS3String,
        ContentType: "application/json",
      })
      .promise();
    const resultMessage = `News data stored in S3: s3://${S3_BUCKET_NAME}/input/${S3_OBJECT_KEY}`;
    if (failedSources.length > 0) {
      return {
        statusCode: 201,
        body: `${resultMessage} with partial failure. Failed sources: ${failedSources}`,
        data: failedSources,
      };
    }

    return {
      statusCode: 200,
      body: resultMessage,
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: `Error: ${error.message}`,
    };
  }
};
