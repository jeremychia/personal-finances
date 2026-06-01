with
source as (select * from {{ source("google_sheets", "sg_eur_revolut_v2") }}),

renamed as (
    select
        'revolut-eur' as bank_source,
        'EUR' as local_currency,
        category,
        description,
        date(
            parse_datetime('%d/%m/%Y %H:%M', started_date)
        ) as local_date,
        safe_cast(amount as float64) as local_amount
    from source
)

select *
from renamed
