SELECT COUNT(*) AS "total_events", COUNT(DISTINCT data ->> 'event_id') AS "unique_events"
FROM raw.events;
