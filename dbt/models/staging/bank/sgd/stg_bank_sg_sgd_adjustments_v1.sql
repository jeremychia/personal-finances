with
source as (select * from {{ source("bank", "sg_sgd_adjustments") }}),

renamed as (
    select
        'adjustments-sgd' as bank_source,
        'SGD' as local_currency,
        amount as local_amount,
        category,
        remarks as description,
        date_sub(
            date_add(
                parse_date('%Y-%m', yyyymm), interval 1 month
            ),
            interval 1 day
        ) as local_date

    from source
)

select *
from renamed
