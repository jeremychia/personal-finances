with
source as (select * from {{ source("google_sheets", "sg_sgd_uobcc") }}),

renamed as (
    select
        'uob-cc' as bank_source,
        'SGD' as local_currency,
        category,
        description,
        parse_date(
            '%d-%b-%y', transaction_date
        ) as local_date,
        -safe_cast(
            transaction_amount_local as float64
        ) as local_amount
    from source
)

select *
from renamed
