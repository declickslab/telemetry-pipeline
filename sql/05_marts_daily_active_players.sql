-- Build marts.daily_active_players from staging.events.
-- A player is active on a day if they started at least one session that day.
-- Days are cut in UTC so the result does not depend on the session time zone.
DROP TABLE IF EXISTS marts.daily_active_players;

CREATE TABLE marts.daily_active_players AS
SELECT
  (event_time AT TIME ZONE 'UTC')::date AS day,
  COUNT(DISTINCT player_id)             AS active_players
FROM staging.events
WHERE event_type = 'session_start'
GROUP BY 1
ORDER BY 1;
