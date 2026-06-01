{{ config(materialized="table") }}

-- from ECB source:
-- see
-- https://colab.research.google.com/drive/1Q_o7G1MGX1zuT70Nh4yYSmmXH0MN_32k?authuser=1#scrollTo=who6KwTVwP99
{% set currencies = ["CHF", "GBP", "HKD", "HUF", "MYR", "SGD", "USD"] %}

with
source as (
    select
        source_currency,  -- this is EUR
        target_currency,  -- this can be SGD, HUF, etc.
        date,
        amount
    from {{ source("fx", "fx_eur") }}
),

base_dates as (select local_date from {{ ref("dim_dates") }}),

{% for currency in currencies %}
    source_{{ currency }} as (
        select
            cast(date as date) as local_date,
            cast(amount as float64) as exchange_rate
        from source
        where target_currency = '{{ currency }}'
    ),

    base_dates_{{ currency }} as (
        select
            cast(base_dates.local_date as date) as local_date,
            '{{ currency }}' as currency,
            source_{{ currency }}.exchange_rate
        from base_dates
        left join
            source_{{ currency }}
            on
                cast(base_dates.local_date as date)
                = date(source_{{ currency }}.local_date)
    ),

    fill_in_previous_day_{{ currency }} as (
        select
            local_date,
            currency,
            -- when there's no rate for the day, fill it in with the following
            -- day's rate
            coalesce(
                exchange_rate,
                lead(exchange_rate, 1) over (
                    partition by currency order by local_date
                ),
                lead(exchange_rate, 2) over (
                    partition by currency order by local_date
                ),
                lead(exchange_rate, 3) over (
                    partition by currency order by local_date
                ),
                lead(exchange_rate, 4) over (
                    partition by currency order by local_date
                )
            ) as exchange_rate
        from base_dates_{{ currency }}
    ),
{% endfor %}

union_all_base_dates as (
    {% for currency in currencies %}
        select
            local_date,
            currency,
            exchange_rate
        from fill_in_previous_day_{{ currency }}
        {% if not loop.last %}
            union all
        {% endif %}
    {% endfor %}
),

get_current_day_rate as (
    select
        current_date() as local_date,
        currency,
        exchange_rate
    from union_all_base_dates
    where local_date = current_date() - 1
),

union_previous_current_day_rate as (
    select *
    from union_all_base_dates
    where local_date < current_date()
    union all
    select *
    from get_current_day_rate
)

select
    local_date,
    1 as eur,
    exchange_rate,
    currency
from union_previous_current_day_rate
