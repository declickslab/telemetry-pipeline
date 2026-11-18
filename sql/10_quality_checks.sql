-- Quality checks: row counts before and after cleaning, and what the cleaning found.
-- Read-only, it does not create anything. Run it any time after building staging.
-- Late event: received more than 1 minute after it happened. In this data, every
-- event arrives either within 30 seconds or after 1 hour or more, nothing in between.
SELECT 1 AS step, 'raw rows' AS check_name, COUNT(*) AS value
FROM raw.events

UNION ALL
SELECT 2, 'distinct event_id in raw', COUNT(DISTINCT data ->> 'event_id')
FROM raw.events

UNION ALL
SELECT 3, 'staging rows', COUNT(*)
FROM staging.events

UNION ALL
SELECT 4, 'rows removed by cleaning (duplicates)',
  (SELECT COUNT(*) FROM raw.events) - (SELECT COUNT(*) FROM staging.events)

UNION ALL
SELECT 5, 'event_id appearing twice in staging (must be 0)', COUNT(*) - COUNT(DISTINCT event_id)
FROM staging.events

UNION ALL
SELECT 6, 'late events kept in staging', COUNT(*)
FROM staging.events
WHERE received_at - event_time > interval '1 minute'

UNION ALL
SELECT 7, 'events in schema version 1', COUNT(*)
FROM staging.events
WHERE schema_version = 1

UNION ALL
SELECT 8, 'events in schema version 2', COUNT(*)
FROM staging.events
WHERE schema_version = 2

UNION ALL
SELECT 9, 'player_registered without country', COUNT(*)
FROM staging.events
WHERE event_type = 'player_registered' AND country IS NULL

UNION ALL
SELECT 10, 'session_start without device_model', COUNT(*)
FROM staging.events
WHERE event_type = 'session_start' AND device_model IS NULL

ORDER BY step;
