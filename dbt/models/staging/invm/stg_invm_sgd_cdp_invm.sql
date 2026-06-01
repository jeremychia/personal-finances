{{ config(
    materialized = "view",
    tags = ["staging", "invm"]
) }}

with
source as (select * from {{ source("google_sheets", "sgd_cdp_invm") }}),

renamed as (
    select
        'SGD' as local_currency_market,
        parse_date('%d/%m/%Y', date) as local_date,
        round(
            safe_cast(market_unit_price_sgd as float64)
            * safe_cast(quantity as float64),
            2
        ) as local_market,
        safe_cast(base_sgd as float64) as sgd_base,
        concat('CDP - ', counter) as investment_source,
        safe_cast(is_redeemed as boolean) as is_redeemed

    from source
)

select *
from renamed
