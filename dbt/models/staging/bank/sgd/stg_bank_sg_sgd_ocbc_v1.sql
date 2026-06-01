with
source as (select * from {{ source("bank", "sg_sgd_ocbc_v1") }}),

renamed as (
    select
        'ocbc' as bank_source,
        'SGD' as local_currency,
        sgd as local_amount,
        category,
        description,
        parse_date(
            '%d/%m/%Y', transaction_date
        ) as local_date

    from source
)

select *
from renamed
