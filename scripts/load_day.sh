#!/usr/bin/env bash
# Load one day of events (one JSONL file) into raw.events, safely repeatable.
# Usage: bash scripts/load_day.sh 2026-10-05   (run from the repository root)
# In a single transaction (psql --single-transaction) the rows of that file are deleted, then the file is
# loaded again. Running it twice for the same day gives the same table.
set -euo pipefail

day="$1"
file="data/raw_events/events_${day}.jsonl"
[ -f "$file" ] || { echo "No file for $day: $file" >&2; exit 1; }
name="$(basename "$file")"

{
  echo "DELETE FROM raw.events WHERE source_file = '${name}';"
  # Quote and delimiter are control characters that never appear in the JSON,
  # so each line is loaded whole into the single jsonb column.
  echo "COPY raw.events (data) FROM STDIN WITH (FORMAT csv, QUOTE e'\x01', DELIMITER e'\x02');"
  cat "$file"
  echo '\.'
  echo "UPDATE raw.events SET source_file = '${name}' WHERE source_file IS NULL;"
} | docker compose exec -T postgres psql -U telemetry -d telemetry -v ON_ERROR_STOP=1 --single-transaction -q
echo "Loaded $name"
