# relationships_verbose Test Guide

## What is it?

A custom dbt test that validates foreign key relationships and displays problematic values clearly.

## When a test fails

The test returns rows showing which values were not found in the reference table:

```
unrecognised_category | occurrences
ForeignCategory       | 5
UnknownValue          | 2
```

### Finding the problematic values

When `dbt test` reports a failure like:
```
Failure in test source_relationships_verbose_google_sheets_de_eur_milesmore_ftl_db_category...
  Got 1 result, configured to fail if != 0
  compiled code at target/compiled/personal_finances/models/.../source_relationships_verbose_g_1823eeb088108e89a2023dacd1ad9b8a.sql
```

**Option 1: View the compiled SQL**

Open the compiled SQL file path shown above. It contains the exact query that was executed. Copy it and run in BigQuery to see the results.

**Option 2: Check dbt test results in CLI output**

Run:
```bash
dbt test --show
```

This will print the first few rows of each failing test.

**Option 3: Run the source query directly**

```sql
-- For de_eur_milesmore_ftl_db, the test query is approximately:
with child as (
    select category as from_field
    from `jeremy-chia`.`google_sheets`.`de_eur_milesmore_ftl_db`
    where category is not null
),
parent as (
    select category as to_field
    from `jeremy-chia`.`prod_seeds`.`categories`
)
select
    child.from_field as unrecognised_category,
    count(*) as occurrences
from child
left join parent on child.from_field = parent.to_field
where parent.to_field is null
group by 1
order by occurrences desc
```

## How to fix

When the test fails with unrecognised values:

1. **Add the missing values to the seed file:**
   - Open `dbt/seeds/categories.csv`
   - Add a new row for each unrecognised value
   - Include appropriate values for `category2`, `category3`, and `fixed_vs_variable` columns

2. **Reload the seed:**
   ```bash
   dbt seed --select categories
   ```

3. **Re-run the test:**
   ```bash
   dbt test --select source:google_sheets.<table_name>
   ```

## Files involved

- **Test macro:** `dbt/macros/relationships_verbose.sql`
- **YAML configuration:** `dbt/models/staging/bank/gsheet/gsheet_sources.yml` (lines with `relationships_verbose:`)
- **Seed file:** `dbt/seeds/categories.csv`
