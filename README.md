# Solving business questions with news category data set

## Fields of the dataset

For each article the attribute are as follows:
| Attribute | Attribute |Description |
|------------------- |--------------------|--------------------|
| category |string| category article belongs to |
| headline |string| headline of the article |
| authors |string| person authored the article |
| link |string| link to the post |
| short_description |string| short description of the article |
| date |string| date the article was published|

## Fields of supplementary data from news api
Source: https://newsapi.org/
For each article the attribute are as follows:
| Attribute | Attribute | Description|
|------------------- |--------------------| --------------------|
|source_id	|string| id of news agency|
|source_name	|string| name of news agency|
|author	|string| author of article|
|title	|string| title of article|
|description	|string| description of article|
|url	|string| url to article|
|urltoimage	|string| url to image|
|publishedat	|string| when was the article published|

## Business question 1:

**Business Question:** Can we visualize the number of articles produced each year by various news agencies?<br/>
**Target beneficiary:** News Agencies

## Business question 2:

**Business Question:** Can we aggregate all past news articles that are valid and create a search engine? <br/>
**Target beneficiary:** Researchers / General public

## Business question 3:

**Business Question:** Can we have recommendations for categorizing articles? <br/>
**Target beneficiary:** Article authors

---

## How to set up the project

1. Clone the repository
2. Under lambda/get_news directory, run `npm install`
3. Under the terraform directory, place the terraform.tfvars file with the following content:

```
AWS_ACCESS_KEY_ID     = "your_aws_access_key_id"
AWS_SECRET_ACCESS_KEY = "your_aws_secret_access_key"
NEWS_API_KEY          = "your_news_api_key"
AWS_ACCOUNT_ID        = "your_aws_account_id"
AWS_REGION            = "your_aws_region"
```

- :memo: **Note:** the news api key can be retrieved from https://newsapi.org/

3. Run the following commands:

```
terraform init
terraform apply
```

4. Once the terraform is applied, the architecture will be created in AWS.
   ![alt text](image.jpg)

**For the scheduled triggers:**
- 1200 daily => lambda get_news
- 1220 daily => glue crawler
- 1240 daily => glue ETL job
---

**Citation of data sources:**

1. Misra, Rishabh. "News Category Dataset." arXiv preprint arXiv:2209.11429 (2022).
2. Misra, Rishabh and Jigyasa Grover. "Sculpting Data for ML: The first act of Machine Learning." ISBN 9798585463570 (2021).
3. https://www.kaggle.com/datasets/rmisra/news-category-dataset
