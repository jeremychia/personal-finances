with
source as (
    select *
    from {{ source("google_sheets", "gb_gbp_wise") }}
    where lower(currency) = 'gbp'
),

renamed as (
    select
        'wise-gbp' as bank_source,
        'GBP' as local_currency,
        category,
        description,
        parse_date('%d-%m-%Y', date) as local_date,
        safe_cast(amount as float64) as local_amount

    from source
)

select *
from renamed
