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

get_last_value as (
    select
        *,
        lag(coalesce(local_market, 0), 1) over investment_by_date
            as last_local_market,
        lag(coalesce(sgd_market, 0), 1) over investment_by_date as last_sgd_market,
        lag(coalesce(sgd_invm_gain_loss, 0), 1) over investment_by_date
            as last_sgd_invm_gain_loss,
        lag(coalesce(sgd_fx_gain_loss, 0), 1) over investment_by_date
            as last_sgd_fx_gain_loss
    from line_items
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
        sgd_currency_market,
        round(
            coalesce(local_market, 0) - coalesce(last_local_market, 0), 2
        ) as change_local_market,
        round(
            coalesce(sgd_market, 0) - coalesce(last_sgd_market, 0), 2
        ) as change_sgd_market,
        -- use is_redeemed = false to not set include the change in p/l
        round(
            if(
                is_redeemed = false,
                coalesce(sgd_invm_gain_loss, 0)
                - coalesce(last_sgd_invm_gain_loss, 0),
                0
            ),
            2
        ) as change_sgd_invm_gain_loss,
        round(
            if(
                is_redeemed = false,
                coalesce(sgd_fx_gain_loss, 0) - coalesce(last_sgd_fx_gain_loss, 0),
                0
            ),
            2
        ) as change_sgd_fx_gain_loss
    from get_last_value
)

select *
from calc_change_in_value
order by investment_source, local_date
