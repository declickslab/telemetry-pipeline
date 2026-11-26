-- Row counts of the raw table and of every dbt model on Snowflake.
SELECT 'raw.events' AS table_name, COUNT(*) AS row_count FROM telemetry.raw.events
UNION ALL SELECT 'stg_events', COUNT(*) FROM telemetry.dbt_staging.stg_events
UNION ALL SELECT 'sessions', COUNT(*) FROM telemetry.dbt_marts.sessions
UNION ALL SELECT 'daily_active_players', COUNT(*) FROM telemetry.dbt_marts.daily_active_players
UNION ALL SELECT 'milestone_funnel', COUNT(*) FROM telemetry.dbt_marts.milestone_funnel
UNION ALL SELECT 'retention', COUNT(*) FROM telemetry.dbt_marts.retention
UNION ALL SELECT 'app_version_health', COUNT(*) FROM telemetry.dbt_marts.app_version_health;
