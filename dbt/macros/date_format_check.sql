{% macro test_date_fmt(model, column_name, date_format) %}
{%- if execute -%}
  {%- set invalid_rows = run_query("
    select " ~ column_name ~ " as date_value
    from " ~ model ~ "
    where " ~ column_name ~ " is not null
      and safe.parse_date(" ~ date_format ~ ", " ~ column_name ~ ") is null
  ") -%}

  {%- if invalid_rows | length > 0 -%}
    {%- do log("ERROR: Date format validation failed for column '" ~ column_name ~ "'", info=True) -%}
    {%- do log("Expected format: " ~ date_format, info=True) -%}
    {%- set total_count = run_query("
      select count(*) as cnt
      from " ~ model ~ "
      where " ~ column_name ~ " is not null
        and safe.parse_date(" ~ date_format ~ ", " ~ column_name ~ ") is null
    ") -%}
    {%- set total = total_count.rows[0][0] -%}
    {%- do log("Found " ~ total ~ " invalid date(s). Sample values:", info=True) -%}
    {%- for row in invalid_rows.rows -%}
      {%- do log("  - '" ~ row[0] ~ "'", info=True) -%}
    {%- endfor -%}
    {%- if total > 20 -%}
      {%- do log("  ... and " ~ (total - 20) ~ " more", info=True) -%}
    {%- endif -%}
  {%- endif -%}
{%- endif -%}

select
  'INVALID_DATE_FORMAT' as validation_error,
  {{ column_name }} as actual_value,
  {{ date_format }} as expected_format,
  *
from {{ model }}
where {{ column_name }} is not null
  and safe.parse_date({{ date_format }}, {{ column_name }}) is null
{% endmacro %}
