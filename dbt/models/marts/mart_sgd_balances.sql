with
invm as (
    select
        'investment' as account_type,
        local_date,
        investment_source as source_name,
        local_currency_market as local_currency,
        local_market as local_balance,
        sgd_currency_market as sgd_currency,
        sgd_market as sgd_balance,
        cumulative_sgd_invm_gain_loss as sgd_invm_gain_loss,
        cumulative_sgd_fx_gain_loss as sgd_fx_gain_loss
    from {{ ref("mart_sgd_invm_balances") }}
),

bank as (
    select
        case when bank_source like '%cc' then 'credit-card' else 'cash' end as account_type,
        local_date,
        bank_source as source_name,
        local_currency,
        local_balance,
        sgd_currency,
        sgd_amount as sgd_balance,
        0 as sgd_invm_gain_loss,
        sgd_fx_gain_loss
    from {{ ref("mart_sgd_bank_balances") }}
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
