with
source as (
    select *
    from {{ source("google_sheets", "us_usd_wise") }}
    where lower(source_currency) = 'usd'
),

renamed as (
    select
        'wise-usd' as bank_source,
        cast(
            parse_datetime(
                '%Y-%m-%d %H:%M:%S', created_on
            ) as date
        ) as local_date,
        'USD' as local_currency,
        category,
        target_name as description,
        case
            when lower(direction) = 'in'
                then
                    safe_cast(
                        source_amount_after_fees as float64
                    )
            when lower(direction) = 'out'
                then
                    -safe_cast(
                        source_amount_after_fees as float64
                    )
        end as local_amount

    from source
)

select *
from renamed
