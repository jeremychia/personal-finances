with source as (
    select
        local_date,
        sgd,
        exchange_rate,
        currency
    from {{ ref("stg_fx_fx_sgd_from_eur_ecb") }}
),

backfill_by_currency as (
    select
        local_date,
        sgd,
        coalesce(
            exchange_rate,
            lag(exchange_rate, 1) over (partition by currency order by local_date),
            lag(exchange_rate, 2) over (partition by currency order by local_date),
            lag(exchange_rate, 3) over (partition by currency order by local_date),
            lag(exchange_rate, 4) over (partition by currency order by local_date),
            lag(exchange_rate, 5) over (partition by currency order by local_date)
        ) as exchange_rate,
        currency
    from source
)

select
    local_date,
    sgd,
    exchange_rate,
    currency
from backfill_by_currency
