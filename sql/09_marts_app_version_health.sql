-- Build marts.app_version_health from marts.sessions.
-- One row per app version: number of sessions, crash count and rate,
-- and average session length in seconds.
DROP TABLE IF EXISTS marts.app_version_health;

CREATE TABLE marts.app_version_health AS
SELECT
  app_version,
  COUNT(*)                                                              AS sessions,
  COUNT(*) FILTER (WHERE reason = 'crash')                              AS crashes,
  ROUND(100.0 * COUNT(*) FILTER (WHERE reason = 'crash') / COUNT(*), 2) AS crash_rate_pct,
  ROUND(AVG(duration_ms) / 1000)                                        AS avg_session_seconds
FROM marts.sessions
GROUP BY app_version
ORDER BY app_version;
