-- One row per app version: number of sessions, crash count and rate,
-- and average session length in seconds.
select
  app_version,
  count(*)                                                              as sessions,
  count(case when reason = 'crash' then 1 end)                          as crashes,
  round(100.0 * count(case when reason = 'crash' then 1 end) / count(*), 2) as crash_rate_pct,
  round(avg(duration_ms) / 1000)                                        as avg_session_seconds
from {{ ref('sessions') }}
group by app_version
order by app_version
