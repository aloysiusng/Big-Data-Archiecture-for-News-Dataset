SELECT
  EXTRACT(YEAR FROM date) AS publication_year,
  category,
  COUNT(*) AS article_count
FROM
  news_category_dataset_v3_json
WHERE
  EXTRACT(YEAR FROM date) IS NOT NULL
GROUP BY
  EXTRACT(YEAR FROM date),
  category
ORDER BY
  publication_year DESC,
  article_count DESC
;
