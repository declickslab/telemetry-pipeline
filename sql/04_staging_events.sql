-- Build staging.events from raw.events.
-- One row per event_id (first received copy), typed columns,
-- and both app formats merged into one set of columns.
DROP TABLE IF EXISTS staging.events;

CREATE TABLE staging.events AS
WITH ranked AS (
  SELECT
    data,
    ROW_NUMBER() OVER (
      PARTITION BY data ->> 'event_id'
      ORDER BY data ->> 'received_at'
    ) AS n
  FROM raw.events
)
SELECT
  data ->> 'event_id'                         AS event_id,
  data ->> 'event_type'                       AS event_type,
  data ->> 'player_id'                        AS player_id,
  data ->> 'session_id'                       AS session_id,
  data ->> 'platform'                         AS platform,
  data ->> 'app_version'                      AS app_version,
  (data ->> 'schema_version')::int            AS schema_version,
  (data ->> 'event_time')::timestamptz        AS event_time,
  (data ->> 'received_at')::timestamptz       AS received_at,
  -- schema v1 used "milestone", v2 uses "milestone_id"
  COALESCE(
    data -> 'payload' ->> 'milestone_id',
    data -> 'payload' ->> 'milestone'
  )                                           AS milestone_id,
  -- schema v1 stored seconds, v2 stores milliseconds
  COALESCE(
    (data -> 'payload' ->> 'duration_ms')::numeric,
    (data -> 'payload' ->> 'duration_s')::numeric * 1000
  )                                           AS duration_ms,
  data -> 'payload' ->> 'last_milestone'      AS last_milestone,
  data -> 'payload' ->> 'reason'              AS reason,
  data -> 'payload' ->> 'country'             AS country,
  data -> 'payload' ->> 'acquisition_channel' AS acquisition_channel,
  data -> 'payload' ->> 'device_model'        AS device_model
FROM ranked
WHERE n = 1;
