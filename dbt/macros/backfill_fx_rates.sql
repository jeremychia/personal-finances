{% macro backfill_fx_rates(source_relation, base_column) %}
with source as (
    select
        local_date,
        {{ base_column }},
        exchange_rate,
        currency
    from {{ source_relation }}
),

currencies as (
    select distinct currency from source
),

-- dim_dates may not include today or tomorrow yet, so add them explicitly
date_spine as (
    select local_date from {{ ref("dim_dates") }}
    union distinct
    select local_date
    from
        unnest(
            generate_date_array(
                current_date(), date_add(current_date(), interval 1 day)
            )
        ) as local_date
),

spine as (
    select
        date_spine.local_date,
        currencies.currency
    from date_spine
    cross join currencies
),

backfill_by_currency as (
    select
        spine.local_date,
        1 as {{ base_column }},
        coalesce(
            source.exchange_rate,
            lag(source.exchange_rate, 1) over (partition by spine.currency order by spine.local_date),
            lag(source.exchange_rate, 2) over (partition by spine.currency order by spine.local_date),
            lag(source.exchange_rate, 3) over (partition by spine.currency order by spine.local_date),
            lag(source.exchange_rate, 4) over (partition by spine.currency order by spine.local_date),
            lag(source.exchange_rate, 5) over (partition by spine.currency order by spine.local_date)
        ) as exchange_rate,
        spine.currency
    from spine
    left join source
        on
            spine.local_date = source.local_date
            and spine.currency = source.currency
)

select
    local_date,
    {{ base_column }},
    exchange_rate,
    currency
from backfill_by_currency
{% endmacro %}
