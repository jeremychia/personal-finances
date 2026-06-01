with source as (
    select
        local_date,
        sgd,
        exchange_rate,
        currency
    from {{ ref("stg_fx_fx_sgd_from_eur_ecb") }}
),

backfill_for_empty_dates as (
    select
        * except (exchange_rate),
        coalesce(
            exchange_rate,
            lag(exchange_rate, 1)
                over (partition by currency order by local_date),
            lag(exchange_rate, 2)
                over (partition by currency order by local_date)
        ) as exchange_rate
    from source
)

select * from backfill_for_empty_dates
