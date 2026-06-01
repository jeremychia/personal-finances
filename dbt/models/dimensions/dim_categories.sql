select
    category,
    category2,
    category3,
    fixed_vs_variable
from {{ ref("categories") }}
