with
source as (select * from {{ source("bank", "sg_sgd_scbcc") }}),

renamed as (
    select
        'scb-cc' as bank_source,
        'SGD' as local_currency,
        category,
        description,
        parse_date('%d/%m/%Y', date) as local_date,
        case
            when sgd_amount like '% DR'
                then
                    -1 * cast(
                        regexp_replace(
                            sgd_amount, '[^0-9.]', ''
                        ) as float64
                    )
            when sgd_amount like '% CR'
                then
                    cast(
                        regexp_replace(
                            sgd_amount, '[^0-9.]', ''
                        ) as float64
                    )
        end as local_amount

    from source
)

select *
from renamed
