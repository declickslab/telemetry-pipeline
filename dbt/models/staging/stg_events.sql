-- One row per event_id (first received copy), typed columns,
-- and both app formats merged into one set of columns.
with ranked as (
  select
    data,
    row_number() over (
      partition by data ->> 'event_id'
      order by data ->> 'received_at'
    ) as n
  from {{ source('raw', 'events') }}
)

select
  data ->> 'event_id'                         as event_id,
  data ->> 'event_type'                       as event_type,
  data ->> 'player_id'                        as player_id,
  data ->> 'session_id'                       as session_id,
  data ->> 'platform'                         as platform,
  data ->> 'app_version'                      as app_version,
  (data ->> 'schema_version')::int            as schema_version,
  (data ->> 'event_time')::timestamptz        as event_time,
  (data ->> 'received_at')::timestamptz       as received_at,
  -- schema v1 used "milestone", v2 uses "milestone_id"
  coalesce(
    data -> 'payload' ->> 'milestone_id',
    data -> 'payload' ->> 'milestone'
  )                                           as milestone_id,
  -- schema v1 stored seconds, v2 stores milliseconds
  coalesce(
    (data -> 'payload' ->> 'duration_ms')::numeric,
    (data -> 'payload' ->> 'duration_s')::numeric * 1000
  )                                           as duration_ms,
  data -> 'payload' ->> 'last_milestone'      as last_milestone,
  data -> 'payload' ->> 'reason'              as reason,
  data -> 'payload' ->> 'country'             as country,
  data -> 'payload' ->> 'acquisition_channel' as acquisition_channel,
  data -> 'payload' ->> 'device_model'        as device_model
from ranked
where n = 1
