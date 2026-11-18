-- Build marts.retention from staging.events and marts.sessions.
-- One row per signup day (cohort), with day-1 and day-7 retention.
-- Day N retention: share of the cohort that started a session exactly N days
-- after signup. Days are cut in UTC.
-- A value is left NULL when the data does not yet cover that day.
DROP TABLE IF EXISTS marts.retention;

CREATE TABLE marts.retention AS
WITH signups AS (
  SELECT player_id, (event_time AT TIME ZONE 'UTC')::date AS signup_day
  FROM staging.events
  WHERE event_type = 'player_registered'
),
active_days AS (
  SELECT DISTINCT player_id, (started_at AT TIME ZONE 'UTC')::date AS active_day
  FROM marts.sessions
)
SELECT
  s.signup_day,
  COUNT(*) AS cohort_size,
  CASE WHEN s.signup_day + 1 <= (SELECT MAX(day) FROM marts.daily_active_players)
       THEN COUNT(d1.player_id) END AS d1_players,
  CASE WHEN s.signup_day + 1 <= (SELECT MAX(day) FROM marts.daily_active_players)
       THEN ROUND(100.0 * COUNT(d1.player_id) / COUNT(*), 1) END AS d1_pct,
  CASE WHEN s.signup_day + 7 <= (SELECT MAX(day) FROM marts.daily_active_players)
       THEN COUNT(d7.player_id) END AS d7_players,
  CASE WHEN s.signup_day + 7 <= (SELECT MAX(day) FROM marts.daily_active_players)
       THEN ROUND(100.0 * COUNT(d7.player_id) / COUNT(*), 1) END AS d7_pct
FROM signups AS s
LEFT JOIN active_days AS d1
  ON d1.player_id = s.player_id AND d1.active_day = s.signup_day + 1
LEFT JOIN active_days AS d7
  ON d7.player_id = s.player_id AND d7.active_day = s.signup_day + 7
GROUP BY s.signup_day
ORDER BY s.signup_day;
