with
source as (
    select *
    from {{ source("google_sheets", "gb_hkd_wise") }}
    where lower(target_currency) = 'hkd'
),

renamed as (
    select
        'wise-hkd' as bank_source,
        cast(
            parse_datetime(
                '%Y-%m-%d %H:%M:%S', created_on
            ) as date
        ) as local_date,
        'HKD' as local_currency,
        category,
        target_name as description,
        case
            when lower(direction) = 'in'
                then
                    safe_cast(
                        target_amount_after_fees as float64
                    )
            when lower(direction) = 'out'
                then
                    -safe_cast(
                        target_amount_after_fees as float64
                    )
        end as local_amount

    from source
)

select *
from renamed
