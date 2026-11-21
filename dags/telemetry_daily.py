"""Daily pipeline for the game telemetry project.

Each run plays one simulated day: it loads that day's JSONL file into
raw.events, then rebuilds the dbt models and runs their tests.

The generated files are already split by day of arrival, so a run for
2026-10-02 reads events_2026-10-02.jsonl. Loading a day twice gives the same
table (the rows of that file are replaced), so any run can be retried safely.
"""
import datetime
import os
from pathlib import Path

import pendulum
import psycopg
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG, get_current_context, task
from airflow.timetables.interval import CronDataIntervalTimetable

RAW_DIR = Path("/opt/airflow/data/raw_events")
DBT_DIR = "/opt/airflow/dbt"
DBT_BIN = "/home/airflow/dbt-venv/bin/dbt"

with DAG(
    dag_id="telemetry_daily",
    # One run per day. The run for a day covers that day (data interval start).
    schedule=CronDataIntervalTimetable("@daily", timezone="UTC"),
    # Three simulated days: 1, 2 and 3 October 2026.
    start_date=pendulum.datetime(2026, 10, 1, tz="UTC"),
    end_date=pendulum.datetime(2026, 10, 3, 23, 59, tz="UTC"),
    catchup=True,
    # One day at a time, in order: dbt rebuilds the same tables on every run.
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": datetime.timedelta(seconds=30)},
) as dag:

    @task
    def load_day() -> int:
        """Replace the rows of this day's file in raw.events, in one transaction."""
        day = get_current_context()["data_interval_start"].strftime("%Y-%m-%d")
        name = f"events_{day}.jsonl"
        path = RAW_DIR / name
        if not path.exists():
            raise FileNotFoundError(path)

        with psycopg.connect(
            host=os.environ["POSTGRES_HOST"],
            dbname="telemetry",
            user="telemetry",
            password=os.environ["POSTGRES_PASSWORD"],
        ) as conn:  # commits at the end of the block, rolls back on error
            with conn.cursor() as cur:
                cur.execute("DELETE FROM raw.events WHERE source_file = %s", (name,))
                cur.execute("CREATE TEMP TABLE incoming (data jsonb) ON COMMIT DROP")
                # Quote and delimiter are control characters that never appear in
                # the JSON, so each line is loaded whole into the jsonb column.
                with cur.copy(
                    "COPY incoming (data) FROM STDIN "
                    "WITH (FORMAT csv, QUOTE E'\\x01', DELIMITER E'\\x02')"
                ) as copy:
                    with path.open("rb") as f:
                        while chunk := f.read(1 << 20):
                            copy.write(chunk)
                cur.execute(
                    "INSERT INTO raw.events (data, source_file) "
                    "SELECT data, %s FROM incoming",
                    (name,),
                )
                cur.execute(
                    "SELECT count(*) FROM raw.events WHERE source_file = %s", (name,)
                )
                rows = cur.fetchone()[0]
        print(f"Loaded {rows} events from {name}")
        return rows

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT_BIN} build --project-dir {DBT_DIR} --profiles-dir {DBT_DIR}",
    )

    load_day() >> dbt_build
