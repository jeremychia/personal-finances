{{ config(materialized="table") }}

with
unioned as (
        {{
            dbt_utils.union_relations(
                relations=[
                    ref("mart_eur_bank_transactions"),
                    ref("mart_sgd_bank_transactions"),
                ],
                source_column_name=None,
            )
        }}
),

renamed as (
    select
        bank_source,
        local_date,
        local_currency,
        local_amount,
        category,
        category2,
        category3,
        fixed_vs_variable,
        description,
        coalesce(eur_currency, sgd_currency) as translated_currency,
        coalesce(eur_amount, sgd_amount) as translated_amount
    from unioned
)

select *
from renamed
