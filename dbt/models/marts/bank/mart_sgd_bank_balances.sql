with
dates as (
    select local_date
    from {{ ref("dim_dates") }}
    where local_date <= date_sub(current_date, interval 1 day)
),

fx as (
    select
        local_date,
        currency,
        exchange_rate
    from {{ ref("fact_sgd_exchange_rates_long") }}
),

agg_local_amounts as (
    select
        bank_source,
        local_date,
        local_currency,
        sum(local_amount) as total_local_amount_by_tx_date,
        sum(sgd_amount) as total_sgd_amount_spot_rate
    from {{ ref("mart_sgd_bank_transactions") }}
    group by all
),

cross_join as (
    select
        dates.local_date,
        agg_local_amounts.bank_source,
        agg_local_amounts.local_date as transaction_date,
        agg_local_amounts.local_currency,
        agg_local_amounts.total_local_amount_by_tx_date,
        agg_local_amounts.total_sgd_amount_spot_rate
    from dates
    cross join agg_local_amounts
),

calculate_balance as (
    select
        local_date,
        bank_source,
        local_currency,
        sum(
            case
                when local_date >= transaction_date
                    then total_local_amount_by_tx_date
            end
        ) as local_balance,
        sum(
            case
                when local_date >= transaction_date then total_sgd_amount_spot_rate
            end
        ) as sgd_spot_rate
    from cross_join
    group by all
),

translate_to_sgd as (
    select
        calculate_balance.local_date,
        calculate_balance.bank_source,
        calculate_balance.local_currency,
        'SGD' as sgd_currency,
        round(calculate_balance.local_balance, 2) as local_balance,
        case
            when calculate_balance.local_currency = 'SGD'
                then 1
            else safe_divide(1, fx.exchange_rate)
        end as exchange_rate,
        round(
            case
                when calculate_balance.local_currency = 'SGD'
                    then calculate_balance.local_balance
                else safe_divide(calculate_balance.local_balance, fx.exchange_rate)
            end,
            2
        ) as sgd_amount,
        round(calculate_balance.sgd_spot_rate, 2) as sgd_spot_rate
    from calculate_balance
    left join
        fx
        on
            calculate_balance.local_date = fx.local_date
            and calculate_balance.local_currency = fx.currency

),

calculate_fx_gain_loss as (
    select
        *,
        round(
            coalesce(sgd_amount, 0) - coalesce(sgd_spot_rate, 0), 2
        ) as sgd_fx_gain_loss
    from translate_to_sgd
)

select *
from calculate_fx_gain_loss
