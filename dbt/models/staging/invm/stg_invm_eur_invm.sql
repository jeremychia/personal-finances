{{ config(
    materialized = "table",
    tags = ["staging", "invm"]
) }}

with
source as (select * from {{ source("google_sheets", "eur_invm") }}),

fx_eur_sgd as (
    select
        local_date,
        currency,
        exchange_rate
    from {{ ref("fact_eur_exchange_rates_long") }}
    where currency = 'SGD'
),

renamed as (
    select
        'EUR' as local_currency_market,
        source.investment as investment_source,
        parse_date('%d/%m/%Y', source.date) as local_date,
        safe_cast(source.market_eur as float64) as local_market,
        safe_cast(source.base_eur as float64) as eur_base,
        round(
            safe_divide(
                safe_cast(source.base_eur as float64),
                fx_eur_sgd.exchange_rate
            ),
            2
        ) as sgd_base,
        safe_cast(source.is_redeemed as boolean) as is_redeemed

    from source
    left join
        fx_eur_sgd
        on parse_date('%d/%m/%Y', source.date) = fx_eur_sgd.local_date
)

select *
from renamed
