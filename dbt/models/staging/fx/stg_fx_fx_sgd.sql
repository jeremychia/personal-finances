with
source as (
    select * from {{ source("google_sheets", "fx_sgd") }}
),

renamed as (
    select
        parse_date('%d/%m/%Y', date) as local_date,
        cast(hkd as float64) as hkd,
        cast(usd as float64) as usd,
        cast(eur as float64) as eur,
        cast(myr as float64) as myr,
        cast(huf as float64) as huf,
        cast(chf as float64) as chf,
        cast(gbp as float64) as gbp
    from source
),

unpivot as (
    select *
    from
        renamed
        unpivot (exchange_rate for currency in (hkd, usd, eur, myr, huf, chf, gbp))
),

-- gsheet will not have the rate in today's terms
add_today_rate as (
    -- takes latest date's rate as today's rate
    select current_date() as local_date, exchange_rate, currency
    from unpivot
    where local_date = current_date() - 1
    union all
    -- append with the rest
    select local_date, exchange_rate, currency
    from unpivot
),

clarity as (
    select
        local_date,
        1 as sgd,
        safe_divide(1, exchange_rate) as exchange_rate,
        upper(currency) as currency
    from add_today_rate
)

select *
from clarity
where exchange_rate is not null
