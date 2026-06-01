with
dates as (
    select local_date
    from {{ ref("dim_dates") }}
    where local_date <= date_sub(current_date, interval 1 day)
),

balance_mvmt as (select * from {{ ref("fact_invm_balances_sgd_movement") }}),

cross_join as (
    select
        balance_mvmt.* except (local_date),
        dates.local_date,
        balance_mvmt.local_date as movement_date
    from dates
    cross join balance_mvmt
),

calculate_balance as (
    select
        local_date,
        investment_source,
        local_currency_market,
        sgd_currency_market,
        round(
            sum(case when local_date >= movement_date then change_local_market end),
            2
        ) as local_market,
        round(
            sum(case when local_date >= movement_date then change_sgd_market end), 2
        ) as sgd_market,
        round(
            sum(
                case
                    when local_date >= movement_date then change_sgd_invm_gain_loss
                end
            ),
            2
        ) as cumulative_sgd_invm_gain_loss,
        round(
            sum(
                case
                    when local_date >= movement_date then change_sgd_fx_gain_loss
                end
            ),
            2
        ) as cumulative_sgd_fx_gain_loss
    from cross_join
    group by all
)

select *
from calculate_balance
order by local_date desc, investment_source asc
