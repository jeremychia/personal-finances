with
source as (select * from {{ source("google_sheets", "sg_sgd_uob") }}),

renamed as (
    select
        'uob' as bank_source,
        'SGD' as local_currency,
        category,
        transaction_description as description,
        parse_date(
            '%d-%b-%y', transaction_date
        ) as local_date,
        coalesce(
            safe_cast(deposit as float64),
            0
        ) - coalesce(
            safe_cast(withdrawal as float64), 0
        ) as local_amount
    from source
)

select *
from renamed
