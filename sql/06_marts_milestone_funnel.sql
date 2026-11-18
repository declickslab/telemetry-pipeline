-- Build marts.milestone_funnel from staging.events.
-- One row per milestone: how many distinct players reached it,
-- and that number as a share of all registered players.
-- Milestones form an ordered funnel, so sorting by players gives the funnel order.
DROP TABLE IF EXISTS marts.milestone_funnel;

CREATE TABLE marts.milestone_funnel AS
SELECT
  milestone_id,
  COUNT(DISTINCT player_id) AS players,
  ROUND(
    100.0 * COUNT(DISTINCT player_id)
    / (SELECT COUNT(DISTINCT player_id)
       FROM staging.events
       WHERE event_type = 'player_registered'),
    1
  ) AS pct_of_registered
FROM staging.events
WHERE event_type = 'milestone_reached'
GROUP BY milestone_id
ORDER BY players DESC;
