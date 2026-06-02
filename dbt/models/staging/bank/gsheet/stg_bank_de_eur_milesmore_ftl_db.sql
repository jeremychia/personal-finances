with
source as (
    select *
    from {{ source("google_sheets", "de_eur_milesmore_ftl_db") }}
    where voucher_date is not null
),

renamed as (
    select
        'miles&more-ftl-db' as bank_source,
        'EUR' as local_currency,
        category,
        parse_date('%m/%d/%Y', voucher_date) as local_date,
        safe_cast(
            replace(payment_currency_amount, ',', '.') as float64
        ) as local_amount,
        trim(reason_for_payment) as description

    from source
)

select *
from renamed
