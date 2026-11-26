-- One row per event_id (first received copy), typed columns,
-- and both app formats merged into one set of columns.
with ranked as (
  select
    data,
    row_number() over (
      partition by {{ json_text('data', ['event_id']) }}
      order by {{ json_text('data', ['received_at']) }}
    ) as n
  from {{ source('raw', 'events') }}
)

select
  {{ json_text('data', ['event_id']) }}      as event_id,
  {{ json_text('data', ['event_type']) }}    as event_type,
  {{ json_text('data', ['player_id']) }}     as player_id,
  {{ json_text('data', ['session_id']) }}    as session_id,
  {{ json_text('data', ['platform']) }}      as platform,
  {{ json_text('data', ['app_version']) }}   as app_version,
  {{ json_text('data', ['schema_version']) }}::int as schema_version,
  {{ utc_timestamp(json_text('data', ['event_time'])) }}  as event_time,
  {{ utc_timestamp(json_text('data', ['received_at'])) }} as received_at,
  -- schema v1 used "milestone", v2 uses "milestone_id"
  coalesce(
    {{ json_text('data', ['payload', 'milestone_id']) }},
    {{ json_text('data', ['payload', 'milestone']) }}
  ) as milestone_id,
  -- schema v1 stored seconds, v2 stores milliseconds (both are whole numbers)
  coalesce(
    {{ json_text('data', ['payload', 'duration_ms']) }}::numeric,
    {{ json_text('data', ['payload', 'duration_s']) }}::numeric * 1000
  ) as duration_ms,
  {{ json_text('data', ['payload', 'last_milestone']) }}      as last_milestone,
  {{ json_text('data', ['payload', 'reason']) }}              as reason,
  {{ json_text('data', ['payload', 'country']) }}             as country,
  {{ json_text('data', ['payload', 'acquisition_channel']) }} as acquisition_channel,
  {{ json_text('data', ['payload', 'device_model']) }}        as device_model
from ranked
where n = 1
