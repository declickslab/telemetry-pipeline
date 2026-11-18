-- A session cannot end before it starts.
-- This test passes when the query returns no rows.
select
  session_id,
  started_at,
  ended_at
from {{ ref('sessions') }}
where ended_at < started_at
