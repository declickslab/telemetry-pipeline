#!/usr/bin/env bash
# Load every JSONL file from data/raw_events into raw.events, one day at a time.
# Safe to run again: each day is replaced, never added twice (see load_day.sh).
# Run it from the repository root.
set -euo pipefail

for f in data/raw_events/events_*.jsonl; do
  day="${f##*/events_}"
  day="${day%.jsonl}"
  bash scripts/load_day.sh "$day"
done
