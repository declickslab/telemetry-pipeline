-- One-time setup of an empty database: the three schemas and the raw events table.
-- Safe to run again, nothing is dropped.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

-- Every event is kept whole in the jsonb column "data", exactly as received.
CREATE TABLE IF NOT EXISTS raw.events (
  data        jsonb       NOT NULL,
  loaded_at   timestamptz NOT NULL DEFAULT now(),
  source_file text        -- name of the JSONL file the event came from, used to reload one day safely
);
