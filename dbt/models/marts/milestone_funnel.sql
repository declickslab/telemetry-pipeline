-- One row per milestone: how many distinct players reached it,
-- and that number as a share of all registered players.
-- Milestones form an ordered funnel, so sorting by players gives the funnel order.
select
  milestone_id,
  count(distinct player_id) as players,
  round(
    100.0 * count(distinct player_id)
    / (select count(distinct player_id)
       from {{ ref('stg_events') }}
       where event_type = 'player_registered'),
    1
  ) as pct_of_registered
from {{ ref('stg_events') }}
where event_type = 'milestone_reached'
group by milestone_id
order by players desc
