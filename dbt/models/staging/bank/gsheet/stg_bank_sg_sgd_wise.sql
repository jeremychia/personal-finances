with
source as (
    select *
    from {{ source("google_sheets", "sg_sgd_wise") }}
    where lower(currency) = 'sgd'
),

renamed as (
    select
        'wise-sgd' as bank_source,
        'SGD' as local_currency,
        category,
        description,
        parse_date('%d/%m/%Y', date) as local_date,
        safe_cast(amount as float64) as local_amount
    from source
)

select *
from renamed
