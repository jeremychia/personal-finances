with
line_items as (
    select
        investment_source,
        local_date,
        local_currency_market,
        local_market,
        sgd_currency_market,
        sgd_market,
        sgd_invm_gain_loss,
        sgd_fx_gain_loss,
        is_redeemed
    from {{ ref("fact_invm_balances_line_items") }}
),

fx_eur as (
    select
        local_date,
        currency,
        exchange_rate
    from {{ ref("fact_eur_exchange_rates_long") }}
),

fx_sgd_eur as (
    select
        local_date,
        currency,
        exchange_rate
    from fx_eur
    where currency = 'SGD'
),

convert_to_eur as (
    select
        line_items.investment_source,
        line_items.local_date,
        line_items.local_currency_market,
        'EUR' as eur_currency_market,
        line_items.local_market,
        round(
            safe_divide(line_items.sgd_market, fx_sgd_eur.exchange_rate),
            2
        ) as eur_market,
        round(
            safe_divide(line_items.sgd_invm_gain_loss, fx_sgd_eur.exchange_rate),
            2
        ) as eur_invm_gain_loss,
        round(
            safe_divide(line_items.sgd_fx_gain_loss, fx_sgd_eur.exchange_rate),
            2
        ) as eur_fx_gain_loss,
        line_items.is_redeemed
    from line_items
    left join
        fx_sgd_eur
        on
            line_items.local_date = fx_sgd_eur.local_date
),

get_last_value as (
    select
        *,
        lag(coalesce(local_market, 0), 1) over investment_by_date
            as last_local_market,
        lag(coalesce(eur_market, 0), 1) over investment_by_date as last_eur_market,
        lag(coalesce(eur_invm_gain_loss, 0), 1) over investment_by_date
            as last_eur_invm_gain_loss,
        lag(coalesce(eur_fx_gain_loss, 0), 1) over investment_by_date
            as last_eur_fx_gain_loss
    from convert_to_eur
    window
        investment_by_date as (
            partition by investment_source, local_currency_market order by local_date
        )
),

calc_change_in_value as (
    select
        investment_source,
        local_date,
        local_currency_market,
        eur_currency_market,
        round(
            coalesce(local_market, 0) - coalesce(last_local_market, 0), 2
        ) as change_local_market,
        round(
            coalesce(eur_market, 0) - coalesce(last_eur_market, 0), 2
        ) as change_eur_market,
        round(
            if(
                is_redeemed = false,
                coalesce(eur_invm_gain_loss, 0)
                - coalesce(last_eur_invm_gain_loss, 0),
                0
            ),
            2
        ) as change_eur_invm_gain_loss,
        round(
            if(
                is_redeemed = false,
                coalesce(eur_fx_gain_loss, 0) - coalesce(last_eur_fx_gain_loss, 0),
                0
            ),
            2
        ) as change_eur_fx_gain_loss
    from get_last_value
)

select *
from calc_change_in_value
order by investment_source, local_date
