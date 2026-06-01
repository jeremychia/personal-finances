with
source as (select * from {{ source("google_sheets", "sg_sgd_dbs") }}),

renamed as (
    select
        'dbs' as bank_source,
        'SGD' as local_currency,
        category,
        parse_date(
            '%d-%b-%y', transaction_date
        ) as local_date,
        coalesce(
            safe_cast(credit_amount as float64),
            0
        ) - coalesce(
            safe_cast(debit_amount as float64), 0
        ) as local_amount,
        concat(
            coalesce(transaction_ref1, ''),
            ' ',
            coalesce(transaction_ref2, ''),
            ' ',
            coalesce(transaction_ref3, '')
        ) as description

    from source
)

select *
from renamed
order by local_date desc
