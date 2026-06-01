with
source as (select * from {{ source("google_sheets", "sg_sgd_revolut_v2") }}),

renamed as (
    select
        'revolut-sgd' as bank_source,
        'SGD' as local_currency,
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
