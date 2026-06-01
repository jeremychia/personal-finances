with
source as (select * from {{ source("google_sheets", "fr_eur_hsbcfr") }}),

renamed as (
    select
        'hsbc-fr' as bank_source,
        'EUR' as local_currency,
        category,
        description,
        parse_date('%d/%m/%Y', operation) as local_date,
        coalesce(
            cast(
                replace(
                    replace(credit, ',', '.'), ' ', ''
                ) as float64
            ),
            0
        ) + coalesce(
            cast(
                replace(
                    replace(debit, ',', '.'), ' ', ''
                ) as float64
            ),
            0
        ) as local_amount

    from source
)

select *
from renamed
