with
source as (select * from {{ source("bank", "sg_sgd_citicc") }}),

renamed as (
    select
        'citi-cc' as bank_source,
        'SGD' as local_currency,
        amount as local_amount,
        category,
        description,
        parse_date(
            '%d/%m/%Y', transaction_date
        ) as local_date

    from source
)

select *
from renamed
