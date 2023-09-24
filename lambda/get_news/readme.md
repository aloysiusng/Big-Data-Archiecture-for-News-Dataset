# Before terraform apply
please `npm install` in this directory

# continuation with paid API key
due to the free API Key limitations, we can only fetch up to 100 articles at a time
<br/>
search for `<insertion>` in `get_news.py` and add some logic to go down the pages and fetch more articles
<br/>
add the following code below and adjust the indentation

```python
prefetch = requests.get(
        NEWS_API_EVERYTHING_URL,
        headers=HEADERS,
        params={
            "sources": source_ids,
            "language": LANGUAGE,
            "pageSize": PAGE_SIZE,
            "page": page,
        },
    )

if prefetch.status_code == 200:
    top_headlines_to_S3.append(prefetch.json()["articles"])
PAGE_LIMIT = prefetch.json()["totalResults"]

while page < PAGE_LIMIT:
```
