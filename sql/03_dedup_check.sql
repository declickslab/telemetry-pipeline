-- Count the rows kept after deduplication.
-- Keeps the first received copy of each event_id.
-- Expected result: 1097789 (the distinct event_id count).
WITH ranked AS (
  SELECT
    data,
    ROW_NUMBER() OVER (
      PARTITION BY data ->> 'event_id'
      ORDER BY data ->> 'received_at'
    ) AS n
  FROM raw.events
)
SELECT COUNT(*) AS kept_rows
FROM ranked
WHERE n = 1;