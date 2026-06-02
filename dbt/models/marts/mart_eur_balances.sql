with
invm as (
    select
        'investment' as account_type,
        local_date,
        investment_source as source_name,
        local_currency_market as local_currency,
        local_market as local_balance,
        eur_currency_market as eur_currency,
        eur_market as eur_balance,
        cumulative_eur_invm_gain_loss as eur_invm_gain_loss,
        cumulative_eur_fx_gain_loss as eur_fx_gain_loss
    from {{ ref("mart_eur_invm_balances") }}
),

bank as (
    select
        case when bank_source like '%cc' then 'credit-card' else 'cash' end as account_type,
        local_date,
        bank_source as source_name,
        local_currency,
        local_balance,
        eur_currency,
        eur_amount as eur_balance,
        0 as eur_invm_gain_loss,
        eur_fx_gain_loss
    from {{ ref("mart_eur_bank_balances") }}
),

unioned as (
    select *
    from invm
    union all
    select *
    from bank
),

add_day_of_week as (
    select
        unioned.*,
        dates.day_of_week_iso
    from unioned
    left join
        {{ ref("dim_dates") }} as dates
        on unioned.local_date = dates.local_date
),

add_latest_date_flag as (
    select
        *,
        if(local_date = max(local_date) over (), true, false) as is_latest_date
    from add_day_of_week
)

select *
from add_latest_date_flag
order by local_date desc, source_name asc
