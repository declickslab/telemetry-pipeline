-- One row per signup day (cohort), with day-1 and day-7 retention.
-- Day N retention: share of the cohort that started a session exactly N days
-- after signup. Days are cut in UTC.
-- A value is left NULL when the data does not yet cover that day.
with signups as (
  select player_id, {{ utc_date('event_time') }} as signup_day
  from {{ ref('stg_events') }}
  where event_type = 'player_registered'
),

active_days as (
  select distinct player_id, {{ utc_date('started_at') }} as active_day
  from {{ ref('sessions') }}
)

select
  s.signup_day,
  count(*) as cohort_size,
  case when s.signup_day + 1 <= (select max(day) from {{ ref('daily_active_players') }})
       then count(d1.player_id) end as d1_players,
  case when s.signup_day + 1 <= (select max(day) from {{ ref('daily_active_players') }})
       then round(100.0 * count(d1.player_id) / count(*), 1) end as d1_pct,
  case when s.signup_day + 7 <= (select max(day) from {{ ref('daily_active_players') }})
       then count(d7.player_id) end as d7_players,
  case when s.signup_day + 7 <= (select max(day) from {{ ref('daily_active_players') }})
       then round(100.0 * count(d7.player_id) / count(*), 1) end as d7_pct
from signups as s
left join active_days as d1
  on d1.player_id = s.player_id and d1.active_day = s.signup_day + 1
left join active_days as d7
  on d7.player_id = s.player_id and d7.active_day = s.signup_day + 7
group by s.signup_day
order by s.signup_day
