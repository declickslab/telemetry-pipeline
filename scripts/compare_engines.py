"""Check that the dbt models give the same results on Postgres and on Snowflake.

The four small analysis tables are compared row by row. The two large ones
(stg_events, sessions) are compared through counts, sums and date ranges.

Run after `dbt build` on both targets, from the repository root:
    .venv-snowflake/bin/python scripts/compare_engines.py
Needs the Snowflake variables and POSTGRES_PASSWORD in the environment.
"""
import datetime
import os
import sys
from decimal import Decimal

import psycopg
import snowflake.connector

# {utc} becomes the expression that shows a timestamp as plain UTC on each engine.
QUERIES = {
    "stg_events (summary)": """
        select count(*), count(distinct event_id), count(distinct player_id),
               count(session_id), count(milestone_id), count(duration_ms), sum(duration_ms),
               count(country), count(device_model), sum(schema_version),
               min({event_time}), max({event_time}), min({received_at}), max({received_at})
        from dbt_staging.stg_events""",
    "sessions (summary)": """
        select count(*), count(distinct session_id), count(distinct player_id),
               sum(duration_ms), sum(event_count), count(last_milestone),
               count(case when reason = 'crash' then 1 end),
               min({started_at}), max({ended_at})
        from dbt_marts.sessions""",
    "daily_active_players": "select day, active_players from dbt_marts.daily_active_players order by day",
    "milestone_funnel": "select milestone_id, players, pct_of_registered from dbt_marts.milestone_funnel order by milestone_id",
    "retention": "select signup_day, cohort_size, d1_players, d1_pct, d7_players, d7_pct from dbt_marts.retention order by signup_day",
    "app_version_health": "select app_version, sessions, crashes, crash_rate_pct, avg_session_seconds from dbt_marts.app_version_health order by app_version",
}
TIME_COLUMNS = ("event_time", "received_at", "started_at", "ended_at")


def normalise(value):
    """Make values from the two drivers comparable (1 == Decimal('1.0'), etc.)."""
    if isinstance(value, (int, float, Decimal)):
        return round(float(value), 6)
    if isinstance(value, datetime.datetime):
        return value.replace(tzinfo=None)
    return value


def fetch(cursor, query):
    cursor.execute(query)
    return [tuple(normalise(v) for v in row) for row in cursor.fetchall()]


def main() -> None:
    pg_times = {c: f"{c} at time zone 'UTC'" for c in TIME_COLUMNS}
    sf_times = {c: c for c in TIME_COLUMNS}  # already stored as UTC

    with psycopg.connect(
        host=os.environ.get("POSTGRES_HOST", "localhost"),
        dbname="telemetry",
        user="telemetry",
        password=os.environ["POSTGRES_PASSWORD"],
    ) as pg, snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role="ACCOUNTADMIN",
        warehouse="telemetry_wh",
        database="telemetry",
    ) as sf:
        different = 0
        with pg.cursor() as pg_cur, sf.cursor() as sf_cur:
            for name, query in QUERIES.items():
                left = fetch(pg_cur, query.format(**pg_times))
                right = fetch(sf_cur, query.format(**sf_times))
                if left == right:
                    print(f"SAME       {name}: {len(left)} row(s)")
                    continue
                different += 1
                print(f"DIFFERENT  {name}: {len(left)} rows on Postgres, {len(right)} on Snowflake")
                for a, b in [(a, b) for a, b in zip(left, right) if a != b][:3]:
                    print(f"           postgres:  {a}\n           snowflake: {b}")
        if different:
            sys.exit(f"{different} result(s) differ")
        print("Postgres and Snowflake give the same results.")


if __name__ == "__main__":
    main()
