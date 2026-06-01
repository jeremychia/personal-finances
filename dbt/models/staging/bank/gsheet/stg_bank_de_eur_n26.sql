with
source as (select * from {{ source("google_sheets", "de_eur_n26") }}),

renamed as (
    select
        'n26' as bank_source,
        'EUR' as local_currency,
        category,
        parse_date('%d/%m/%Y', date) as local_date,
        safe_cast(amount_eur as float64) as local_amount,
        trim(
            concat(
                coalesce(
                    cast(payment_reference as string), ''
                ),
                ' ',
                coalesce(cast(payee as string), ''),
                ' ',
                coalesce(cast(account_number as string), '')
            )
        ) as description

    from source
)

select *
from renamed
