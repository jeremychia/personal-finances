{% test relationships_verbose(model, column_name, to, field) %}

{%- set query -%}
with child as (
    select {{ column_name }} as from_field
    from {{ model }}
    where {{ column_name }} is not null
),

parent as (
    select {{ field }} as to_field
    from {{ to }}
),

violations as (
    select
        child.from_field as unrecognised_{{ column_name }},
        count(*) as occurrences

    from child
    left join parent
        on child.from_field = parent.to_field

    where parent.to_field is null

    group by 1
    order by occurrences desc
)

select * from violations
{%- endset -%}

{%- if execute -%}
    {%- set results = run_query(query) -%}
    {%- if results.rows -%}
        {%- set violation_list = [] -%}
        {%- for row in results.rows -%}
            {%- set _ = violation_list.append(row[0] ~ " (" ~ row[1] ~ "x)") -%}
        {%- endfor -%}
        {% do log("❌ RELATIONSHIPS VIOLATION in " ~ model ~ " - Unrecognised " ~ column_name ~ " values: " ~ violation_list | join(", "), info=True) %}
    {%- endif -%}
{%- endif -%}

{{ query }}

{% endtest %}
