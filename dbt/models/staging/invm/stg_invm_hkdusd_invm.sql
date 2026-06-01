{{ config(
    materialized = "view",
    tags = ["staging", "invm"]
) }}

with
source as (
    select
        * except (date),
        parse_date('%d/%m/%Y', date) as local_date
    from {{ source("google_sheets", "hkd_usd_invm") }}
),

fx as (
    select
        cast(hkd as float64) as hkd,
        cast(usd as float64) as usd,
        parse_date('%d/%m/%Y', date) as local_date
    from {{ source("google_sheets", "fx_sgd") }}
),

hkd as (
    select
        local_date,
        'HKD' as local_currency_market,
        safe_cast(market_hkd as float64) as local_market,
        safe_cast(base_hkd as float64) as hkd_base,
        0 as usd_base,
        investment as investment_source,
        safe_cast(is_redeemed as boolean) as is_redeemed
    from source
),

usd as (
    select
        local_date,
        'USD' as local_currency_market,
        safe_cast(market_usd as float64) as local_market,
        0 as hkd_base,
        safe_cast(base_usd as float64) as usd_base,
        investment as investment_source,
        safe_cast(is_redeemed as boolean) as is_redeemed
    from source
),

unioned as (
    select *
    from hkd
    union all
    select *
    from usd
),

translate_to_sgd_base as (
    select
        unioned.local_date,
        unioned.local_currency_market,
        unioned.local_market,
        unioned.hkd_base,
        unioned.usd_base,
        unioned.is_redeemed,
        unioned.investment_source,
        sum(unioned.hkd_base) over (partition by unioned.local_date)
        * fx.hkd as total_hkd_base_in_sgd,
        sum(unioned.usd_base) over (partition by unioned.local_date)
        * fx.usd as total_usd_base_in_sgd
    from unioned
    left join fx on unioned.local_date = fx.local_date
    where unioned.local_date >= '2021-03-12'

),

allocate_sgd_base as (
    select
        translate_to_sgd_base.local_date,
        translate_to_sgd_base.local_currency_market,
        translate_to_sgd_base.local_market,
        translate_to_sgd_base.hkd_base,
        translate_to_sgd_base.usd_base,
        translate_to_sgd_base.is_redeemed,
        translate_to_sgd_base.investment_source,
        case
            when translate_to_sgd_base.local_currency_market = 'HKD'
                then
                    safe_divide(
                        translate_to_sgd_base.total_hkd_base_in_sgd,
                        translate_to_sgd_base.total_hkd_base_in_sgd
                        + translate_to_sgd_base.total_usd_base_in_sgd
                    )
                    * safe_cast(source.base_sgd as float64)
            when translate_to_sgd_base.local_currency_market = 'USD'
                then
                    safe_divide(
                        translate_to_sgd_base.total_usd_base_in_sgd,
                        translate_to_sgd_base.total_hkd_base_in_sgd
                        + translate_to_sgd_base.total_usd_base_in_sgd
                    )
                    * safe_cast(source.base_sgd as float64)
        end as sgd_base
    from translate_to_sgd_base
    left join source on translate_to_sgd_base.local_date = source.local_date
)

select *
from allocate_sgd_base
order by local_date, local_currency_market
