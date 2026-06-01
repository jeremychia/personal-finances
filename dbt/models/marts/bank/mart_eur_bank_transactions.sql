with
bank_local_currency as (
    select
        bank_source,
        local_date,
        local_currency,
        local_amount,
        category,
        description
    from {{ ref("fact_bank_transactions") }}
),

fx as (
    select
        local_date,
        currency,
        exchange_rate
    from {{ ref("fact_eur_exchange_rates_long") }}
),

categories as (
    select
        category,
        category2,
        category3,
        fixed_vs_variable
    from {{ ref("dim_categories") }}
),

joined as (
    select
        local_cur.bank_source,
        local_cur.local_date,
        local_cur.local_currency,
        local_cur.local_amount,
        'EUR' as eur_currency,
        local_cur.category,
        categories.category2,
        categories.category3,
        categories.fixed_vs_variable,
        local_cur.description,
        case
            when local_cur.local_currency = 'EUR'
                then 1
            else safe_divide(1, fx.exchange_rate)
        end as exchange_rate,
        case
            when local_cur.local_currency = 'EUR'
                then local_cur.local_amount
            else safe_divide(local_cur.local_amount, fx.exchange_rate)
        end as eur_amount
    from bank_local_currency as local_cur
    left join
        fx on local_cur.local_date = fx.local_date and local_cur.local_currency = fx.currency
    left join categories on local_cur.category = categories.category
)

select *
from joined
