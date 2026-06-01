with
source as (select * from {{ source("bank", "sg_sgd_hsbccc") }}),

renamed as (
    select
        'hsbc-cc' as bank_source,
        'SGD' as local_currency,
        amount as local_amount,
        category,
        description,
        parse_date('%d/%m/%Y', date) as local_date

    from source
)

select *
from renamed
