# Classifier Setup Checklist

This document outlines the one-time setup steps required before using the category classifier.

## Prerequisites

- A Google Cloud project with BigQuery enabled
- A Google Spreadsheet with transaction data
- Access to dbt (to materialize the fact table)

## Step 1: Service Account Setup

The classifier uses a Google Cloud **service account** to access BigQuery and Google Sheets.

**See [SERVICE_ACCOUNT_SETUP.md](SERVICE_ACCOUNT_SETUP.md) for detailed instructions:**

1. Create or identify a service account
2. Grant **BigQuery Admin** role
3. Share the Google Spreadsheet with the service account email (Editor access)
4. Generate a JSON keyfile and save to `keys/keyfile.json`
5. Verify setup with preflight checks

**If you get an `ACCESS_TOKEN_SCOPE_INSUFFICIENT` error:** Regenerate the JSON keyfile — the current one was created before the BigQuery role was assigned.

## Step 2: Materialize Training Data

The classifier trains on labelled transactions stored in your data warehouse. You need to materialize the fact table:

```bash
dbt run --select fact_bank_transactions
```

This creates the training dataset in BigQuery. Verify it exists:

```bash
# Check your project/dataset/table in BigQuery
bq query "SELECT COUNT(*) FROM your_project.your_dataset.your_table"
```

## Step 3: Install Python Dependencies

```bash
uv sync
# OR
poetry install
```

This installs:
- pandas, scikit-learn (ML)
- gspread, google-cloud-bigquery, google-auth (cloud services)
- sqlglot (SQL parsing)
- pyyaml (configuration)

## Step 4: Configure the Classifier

Edit `classifier/config.yml`:

```yaml
bigquery:
  project: your-gcp-project
  dataset: your-bigquery-dataset
  table: your-fact-table-name
  keyfile: keys/keyfile.json

google_sheets:
  spreadsheet_id: your-spreadsheet-id
  keyfile: keys/keyfile.json
  sheets:
    - sheet_name_1
    - sheet_name_2
    # etc

classifier:
  confidence_threshold: 0.80
  backup_dir: classifier/backups
```

To find your spreadsheet ID, open the spreadsheet and copy the ID from the URL:
```
https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
```

## Step 5: Test the Setup

Run the preflight checks:

```bash
uv run python -m classifier.cli --sheet <sheet_name> --dry-run
```

You should see:
```
=== Preflight Checks ===

1. Testing BigQuery connection...
   ✓ Connected. Table has XXX labelled rows.

2. Testing Google Sheets API access...
   ✓ Spreadsheet opened: ...

3. Checking staging SQL files and description columns...
   ✓ ...

✓ All preflight checks passed.
```

Then proceed with the classifier:

```bash
# Preview predictions (saves to CSV)
uv run python -m classifier.cli --dry-run

# Test on a single sheet
uv run python -m classifier.cli --sheet <sheet_name> --dry-run
uv run python -m classifier.cli --sheet <sheet_name>

# Run on all configured sheets
uv run python -m classifier.cli
```

## Troubleshooting

### "Preflight check failed"

See [SERVICE_ACCOUNT_SETUP.md](SERVICE_ACCOUNT_SETUP.md) for detailed troubleshooting, including:
- `ACCESS_TOKEN_SCOPE_INSUFFICIENT` — Regenerate keyfile
- `Could not authenticate` — Check keyfile path and validity
- `Spreadsheet not found` — Verify sharing and permissions
- `BigQuery table not found` — Run `dbt run --select fact_bank_transactions`

### "No staging SQL file found"

The classifier expects a staging SQL file for each sheet. The naming convention is:
```
dbt/models/staging/bank/gsheet/stg_bank_{sheet_name}.sql
```

Create the staging model or ensure the sheet name matches the SQL filename.

### "No description columns found"

The classifier uses sqlglot to parse the staging SQL and extract which columns compose the `description` field. Check that:
1. The staging SQL has a `description` column or alias
2. The expression is valid BigQuery SQL

## See Also

- [README.md](README.md) — Usage guide and model details
- [SERVICE_ACCOUNT_SETUP.md](SERVICE_ACCOUNT_SETUP.md) — Detailed service account configuration
- `classifier/config.yml` — Configuration reference
