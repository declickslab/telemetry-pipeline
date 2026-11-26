-- One-time setup on Snowflake: a small warehouse, the database, the raw table.
-- Run it in a Snowflake worksheet. Safe to run again, nothing is dropped.

-- Smallest size, switched off after 60 idle seconds, so credits are only spent while working.
CREATE WAREHOUSE IF NOT EXISTS telemetry_wh
  WITH WAREHOUSE_SIZE = 'XSMALL'
       AUTO_SUSPEND = 60
       AUTO_RESUME = TRUE
       INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS telemetry;
CREATE SCHEMA IF NOT EXISTS telemetry.raw;

-- Same idea as the Postgres table: each event is kept whole, exactly as received.
CREATE TABLE IF NOT EXISTS telemetry.raw.events (
  data        VARIANT       NOT NULL,
  loaded_at   TIMESTAMP_NTZ NOT NULL DEFAULT SYSDATE(),  -- SYSDATE() is UTC
  source_file STRING        -- name of the JSONL file the event came from
);

SHOW WAREHOUSES LIKE 'telemetry_wh';
