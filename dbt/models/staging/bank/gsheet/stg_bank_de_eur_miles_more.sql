with
source as (
    select *
    from {{ source("google_sheets", "de_eur_miles_more") }}
    where processed_on is not null
),

renamed as (
    select
        'miles&more-cc' as bank_source,
        'EUR' as local_currency,
        category,
        parse_date('%d.%m.%Y', authorised_on) as local_date,  -- convert european format
        safe_cast(
            replace(
                replace(amount, '.', ''), ',', '.'
            ) as float64
        ) as local_amount,
        trim(description) as description

    from source
)

select *
from renamed
