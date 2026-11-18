-- One row per session: the session_start event joined to its session_end event.
-- Every session in the data has exactly one start and one end.
-- event_count is every event of the session: start, end and the milestones in between.
with session_events as (
  select session_id, count(*) as event_count
  from {{ ref('stg_events') }}
  where session_id is not null
  group by session_id
)

select
  s.session_id,
  s.player_id,
  s.platform,
  s.app_version,
  s.device_model,
  s.event_time as started_at,
  e.event_time as ended_at,
  e.duration_ms,
  e.reason,
  e.last_milestone,
  c.event_count
from {{ ref('stg_events') }} as s
join {{ ref('stg_events') }} as e
  on e.session_id = s.session_id
join session_events as c
  on c.session_id = s.session_id
where s.event_type = 'session_start'
  and e.event_type = 'session_end'
