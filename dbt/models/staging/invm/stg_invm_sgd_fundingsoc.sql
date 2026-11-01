{{ config(
    materialized = "table",
    tags = ["staging", "invm"]
) }}

with
source as (select * from {{ source("google_sheets", "sgd_fundingsoc") }}),

renamed as (
    select
        'SGD' as local_currency_market,
        principal_sgd as sgd_base,
        investment as investment_source,
        parse_date('%d/%m/%Y', date) as local_date,
        coalesce(
            safe_cast(acc_balance_sgd as float64),
            0
        ) + coalesce(
            safe_cast(outstanding_principle_sgd as float64),
            0
        )
        + coalesce(
            safe_cast(expected_returns_sgd as float64), 0
        ) as local_market,
        safe_cast(is_redeemed as boolean) as is_redeemed

    from source
)

select *
from renamed
where local_date >= '2020-01-10'  -- start of investments
