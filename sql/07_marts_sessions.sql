-- Build marts.sessions from staging.events.
-- One row per session: the session_start event joined to its session_end event.
-- Every session in the data has exactly one start and one end.
DROP TABLE IF EXISTS marts.sessions;

CREATE TABLE marts.sessions AS
SELECT
  s.session_id,
  s.player_id,
  s.platform,
  s.app_version,
  s.device_model,
  s.event_time AS started_at,
  e.event_time AS ended_at,
  e.duration_ms,
  e.reason,
  e.last_milestone
FROM staging.events AS s
JOIN staging.events AS e
  ON e.session_id = s.session_id
WHERE s.event_type = 'session_start'
  AND e.event_type = 'session_end';
