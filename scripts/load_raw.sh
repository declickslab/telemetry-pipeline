#!/usr/bin/env bash
# Load every JSONL file from data/raw_events into raw.events.
# Full reload: the table is emptied first, so running the script twice
# gives the same result. Run it from the repository root.
set -euo pipefail

PSQL="docker compose exec -T postgres psql -U telemetry -d telemetry -v ON_ERROR_STOP=1"

$PSQL -c "TRUNCATE raw.events"

for f in data/raw_events/events_*.jsonl; do
  echo "Loading $f"
  # Quote and delimiter are control characters that never appear in the JSON,
  # so each line is loaded whole into the single jsonb column.
  $PSQL -c "COPY raw.events (data) FROM STDIN WITH (FORMAT csv, QUOTE e'\x01', DELIMITER e'\x02')" < "$f"
done
