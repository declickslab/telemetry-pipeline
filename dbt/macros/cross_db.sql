{#- The few places where Postgres and Snowflake differ. The models call these
    macros, and dbt picks the version that matches the target. -#}

{#- Read a key of the raw JSON event as text. path is a list: ['payload', 'reason']. -#}
{% macro json_text(column, path) -%}
  {{ return(adapter.dispatch('json_text', 'telemetry')(column, path)) }}
{%- endmacro %}

{% macro default__json_text(column, path) -%}
  ({{ column }}{% for key in path[:-1] %} -> '{{ key }}'{% endfor %} ->> '{{ path[-1] }}')
{%- endmacro %}

{% macro snowflake__json_text(column, path) -%}
  ({{ column }}:{{ path | join('.') }})::string
{%- endmacro %}

{#- Turn an ISO 8601 UTC string ("2026-10-31T00:00:02Z") into a timestamp.
    On Snowflake the column has no time zone and always holds UTC. -#}
{% macro utc_timestamp(expression) -%}
  {{ return(adapter.dispatch('utc_timestamp', 'telemetry')(expression)) }}
{%- endmacro %}

{% macro default__utc_timestamp(expression) -%}
  ({{ expression }})::timestamptz
{%- endmacro %}

{% macro snowflake__utc_timestamp(expression) -%}
  ({{ expression }})::timestamp_ntz
{%- endmacro %}

{#- The UTC calendar day of such a timestamp. -#}
{% macro utc_date(column) -%}
  {{ return(adapter.dispatch('utc_date', 'telemetry')(column)) }}
{%- endmacro %}

{% macro default__utc_date(column) -%}
  ({{ column }} at time zone 'UTC')::date
{%- endmacro %}

{% macro snowflake__utc_date(column) -%}
  ({{ column }})::date
{%- endmacro %}
