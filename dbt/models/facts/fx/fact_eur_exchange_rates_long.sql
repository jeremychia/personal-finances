select
    local_date,
    eur,
    exchange_rate,
    currency
from {{ ref("stg_fx_fx_eur") }}
