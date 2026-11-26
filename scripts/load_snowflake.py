"""Load the daily JSONL files into telemetry.raw.events on Snowflake.

Same behaviour as scripts/load_day.sh on Postgres: each file replaces its own
rows in one transaction, so loading it again never creates duplicates.

Usage, from the repository root, with .venv-snowflake active:
    python scripts/load_snowflake.py              # every file in data/raw_events
    python scripts/load_snowflake.py 2026-10-05   # only the given day(s)

Connection settings come from the environment (SNOWFLAKE_ACCOUNT,
SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH). No password is used.
"""
import os
import sys
from pathlib import Path

import snowflake.connector

RAW_DIR = Path("data/raw_events").resolve()
STAGE = "@telemetry.raw.events_stage"


def load_file(cur, path: Path) -> int:
    name = path.name
    # 1. Upload the local file to the stage (Snowflake compresses it to .gz).
    cur.execute(f"PUT 'file://{path}' {STAGE} OVERWRITE = TRUE")
    # 2. Replace the rows of this file, all or nothing.
    cur.execute("BEGIN")
    try:
        cur.execute("DELETE FROM telemetry.raw.events WHERE source_file = %s", (name,))
        # FORCE: load the file even if Snowflake remembers having loaded it,
        # since its rows have just been deleted.
        cur.execute(
            f"COPY INTO telemetry.raw.events (data, source_file) "
            f"FROM (SELECT $1, '{name}' FROM {STAGE}/{name}.gz) "
            f"FILE_FORMAT = (TYPE = JSON) FORCE = TRUE PURGE = TRUE"
        )
        cur.execute(
            "SELECT count(*) FROM telemetry.raw.events WHERE source_file = %s", (name,)
        )
        rows = cur.fetchone()[0]
        cur.execute("COMMIT")
    except Exception:
        cur.execute("ROLLBACK")
        raise
    return rows


def main(days: list[str]) -> None:
    if days:
        paths = [RAW_DIR / f"events_{day}.jsonl" for day in days]
    else:
        paths = sorted(RAW_DIR.glob("events_*.jsonl"))
    missing = [p.name for p in paths if not p.exists()]
    if missing or not paths:
        sys.exit(f"No file to load: {missing or RAW_DIR}")

    with snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role="ACCOUNTADMIN",
        warehouse="telemetry_wh",
        database="telemetry",
        schema="raw",
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE STAGE IF NOT EXISTS telemetry.raw.events_stage")
            for path in paths:
                print(f"{path.name}: {load_file(cur, path)} events", flush=True)
            cur.execute("SELECT count(*) FROM telemetry.raw.events")
            print(f"Total in telemetry.raw.events: {cur.fetchone()[0]}")


if __name__ == "__main__":
    main(sys.argv[1:])
