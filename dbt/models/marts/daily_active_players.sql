-- A player is active on a day if they started at least one session that day.
-- Days are cut in UTC so the result does not depend on the session time zone.
select
  {{ utc_date('event_time') }}           as day,
  count(distinct player_id)             as active_players
from {{ ref('stg_events') }}
where event_type = 'session_start'
group by 1
order by 1
