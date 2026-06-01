with
source as (
    select *
    from {{ source("google_sheets", "de_eur_wise") }}
    where lower(currency) = 'eur'
),

renamed as (
    select
        'wise-eur' as bank_source,
        'EUR' as local_currency,
        category,
        description,
        parse_date('%d-%m-%Y', date) as local_date,
        safe_cast(amount as float64) as local_amount

    from source
)

select *
from renamed
