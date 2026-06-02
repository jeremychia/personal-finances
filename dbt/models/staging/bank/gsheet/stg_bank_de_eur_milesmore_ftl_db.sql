-- Miles & More FTL DB staging with N26 transfer offsets
-- Combines Miles & More vouchers with offsetting N26 transfers to balance clearing dates
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
),

-- N26 transfers that funded Miles & More credit cards (reversed to offset)
-- this is because the ledger from credit statements do not have transfers
n26_transfers as (
    select
        'miles&more-ftl-db' as bank_source,
        local_currency,
        category,
        local_date,
        -local_amount as local_amount,
        description
    from {{ ref("stg_bank_de_eur_n26") }}
    where category = 'Transfer'
        and description like '%Deutsche Bank AG%'
        and description like '%DE33500700100707099806%'
        and description like '%5426520204005807%'
),

combined as (
    select * from renamed
    union all
    select * from n26_transfers
)

select *
from combined
