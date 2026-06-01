with
source as (select * from {{ source("google_sheets", "de_eur_amex_payback") }}),

renamed as (
    select
        'amex_payback-cc' as bank_source,
        'EUR' as local_currency,
        category,
        beschreibung as description,
        parse_date('%d/%m/%Y', datum) as local_date,
        -safe_cast(
            replace(betrag, ',', '.') as float64
        ) as local_amount
    from source
)

select *
from renamed
