{% set currencies = ["CHF", "GBP", "HKD", "HUF", "MYR", "USD"] %}  -- everything except EUR

with
fx_eur as (
    select
        local_date,
        eur,
        exchange_rate,
        currency
    from {{ ref("stg_fx_fx_eur") }}
),

eur_sgd_rates as (
    select
        local_date,
        eur,
        exchange_rate,
        currency
    from fx_eur
    where currency = 'SGD'
),

-- create a dummy table
eur_eur_rates as (
    select
        local_date,
        eur,
        1 as exchange_rate,
        'EUR' as currency
    from eur_sgd_rates
),

calc_sgd_eur_rates as (
    select
        eur_eur_rates.local_date,
        1 as sgd,
        safe_divide(
            eur_eur_rates.exchange_rate, eur_sgd_rates.exchange_rate
        ) as exchange_rate,
        eur_eur_rates.currency
    from eur_eur_rates
    left join eur_sgd_rates on eur_eur_rates.local_date = eur_sgd_rates.local_date
),

{% for currency in currencies %}
    eur_{{ currency }}_rates as (
        select
            local_date,
            eur,
            exchange_rate,
            currency
        from fx_eur
        where currency = '{{ currency }}'
    ),

    calc_sgd_{{ currency }}_rates as (
        select
            eur_{{ currency }}_rates.local_date,
            1 as sgd,
            safe_divide(
                eur_{{ currency }}_rates.exchange_rate, eur_sgd_rates.exchange_rate
            ) as exchange_rate,
            eur_{{ currency }}_rates.currency
        from eur_{{ currency }}_rates
        left join
            eur_sgd_rates
            on eur_{{ currency }}_rates.local_date = eur_sgd_rates.local_date
    ),
{% endfor %}

union_all_calc_sgd_rates as (
    {% for currency in currencies %}
        select *
        from calc_sgd_{{ currency }}_rates
        union all
    {% endfor %}
    select *
    from calc_sgd_eur_rates
)

select *
from union_all_calc_sgd_rates
