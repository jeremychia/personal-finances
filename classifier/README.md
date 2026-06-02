# Bank Transaction Category Classifier

Automatically classify blank categories in bank transaction Google Sheets using a machine learning model trained on labelled historical transactions.

## Assumptions

- **All data is in a single Google Spreadsheet** — Multiple sheet tabs (e.g., "N26", "Wise", "DBS") but same spreadsheet
- **Training data exists in a BigQuery fact table** — One unified table with labelled transactions across all sources
- **dbt staging models exist** — SQL files that map raw sheet columns to standard schema (description, amount, category)
- **Staging models follow naming convention** — `dbt/models/staging/bank/gsheet/stg_bank_{sheet_name}.sql`

If your setup differs (e.g., multiple spreadsheets, different directory structure), you can adapt:
- Point `config.yml` to different BigQuery projects/datasets/tables
- Update dbt path assumptions in the classifier code
- Modify which sheets to process in the `sheets` list in `config.yml`

## How it works

1. **Training**: Loads labelled transactions from `fact_bank_transactions` (BigQuery) — the unified fact table of all bank data across all sources
2. **Features**: Uses transaction `description` (text, via TF-IDF) and `local_amount` (numeric, scaled)
3. **Model**: Logistic regression with cross-validation reporting
4. **Inference**: Reads each Google Sheet, finds rows with blank `category` column, predicts categories
5. **Write-back**: Only writes predictions with confidence ≥ threshold (default 0.80). Always backs up sheets before modifying
6. **Description columns**: Automatically extracts which source columns compose `description` by parsing the corresponding staging SQL file

## Quick start

### Prerequisites (one-time setup)

1. **Service Account Setup**
   - Ensure the service account has **BigQuery Admin** role in your GCP project
   - Ensure the service account has **Editor** access on the Google Spreadsheet
   - Generate a fresh JSON keyfile from the service account (Keys → Add Key → JSON)
   - Place the keyfile at `keys/keyfile.json`

2. **Enable APIs in GCP** (if not already enabled)
   - Enable **Google Sheets API**
   - Enable **Google Drive API**

3. **Prepare training data**
   - Run `dbt run --select fact_bank_transactions` to materialize the fact table in BigQuery

4. **Install dependencies**
   - Run `uv sync` (or `poetry install`)

Then:

```bash
# Preview predictions (saves results to classifier/backups/dry_run_YYYY-MM-DD_HH-MM-SS.csv)
uv run python -m classifier.cli --dry-run

# Test on a single sheet
uv run python -m classifier.cli --sheet sg_sgd_dbs --dry-run
uv run python -m classifier.cli --sheet sg_sgd_dbs

# Run on all sheets
uv run python -m classifier.cli
```

**Dry-run mode** prints predictions to console and saves them to a local CSV file so you can review what will be written before actually updating the sheets. Predictions are marked with:
- ✓ (will be written — confidence ≥ threshold)
- ✗ (will NOT be written — confidence < threshold)

## Dry-run results

When you run with `--dry-run`, the classifier:

1. **Prints to console** — All predictions with confidence scores and threshold status (✓/✗)

2. **Saves to CSV** — `classifier/backups/dry_run_YYYY-MM-DD_HH-MM-SS.csv` with all columns:
   - `sheet`: Which sheet tab
   - `description`: Computed transaction description (from staging SQL concat)
   - `local_amount`: Transaction amount
   - `predicted_category`: Category the model predicts
   - `confidence`: Confidence score (0-1)
   - `will_write`: Whether this will be written (confidence ≥ threshold)
   - `source_*` columns: All original sheet columns (Date, Payee, Account number, etc.)

**Example row:**
```
sheet=de_eur_n26
description=(empty — computed from payee + reference + account)
local_amount=6581.49
predicted_category=Food
confidence=0.42
will_write=False
source_Date=29/05/2026
source_Payee=kbht GmbH Wirtschaftsprufungsgesellschaft
source_Payment_reference=Lohn-Gehalt Abrechnung 05/2026
... (all other source columns)
```

This lets you inspect the full data and understand why the model made each prediction before committing them to the sheet.

## Configuration

Edit `classifier/config.yml` to adapt the classifier to your setup:

```yaml
bigquery:
  project: your-gcp-project                    # Change to your GCP project
  dataset: your-dataset                        # Change to your dataset
  table: your-fact-table                       # Change to your training table name
  keyfile: keys/keyfile.json

google_sheets:
  spreadsheet_id: your-spreadsheet-id          # Change to your spreadsheet
  keyfile: keys/keyfile.json
  sheets:                                      # List of sheet tab names to process
    - sheet_tab_1
    - sheet_tab_2
    - sheet_tab_3

classifier:
  confidence_threshold: 0.80                   # Adjust (0-1): higher = more conservative
  backup_dir: classifier/backups               # Where to save backups
```

**To find your Spreadsheet ID:** Open the sheet in your browser, copy the ID from the URL:
```
https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
```

**For different sheet structures:** Update the `sheets` list with your actual tab names. The classifier will:
1. Look for a staging SQL file named `stg_bank_{sheet_name}.sql`
2. Parse it to find which columns compose the description
3. Read the sheet tab with that name from your spreadsheet

## How description columns are extracted

The classifier parses the dbt staging SQL file for each sheet to automatically determine which raw Google Sheet columns compose `description`. For example:

- `sg_sgd_dbs` → reads `stg_bank_sg_sgd_dbs.sql` → extracts `transaction_ref1`, `transaction_ref2`, `transaction_ref3`
- `de_eur_n26` → reads `stg_bank_de_eur_n26.sql` → extracts `payment_reference`, `payee`, `account_number`

Supported patterns:
- Pass-through: `description`
- Single alias: `beschreibung as description`
- Multi-column concat: `concat(...) as description`

## Model

- **Algorithm**: Logistic Regression
- **Features**: TF-IDF (bigrams) on description + scaled amount
- **Cross-validation**: Stratified k-fold, accuracy printed at training time
- **Confidence**: Calibrated probability from `predict_proba`
- **Write-back**: Only predictions with confidence ≥ threshold

## Backups

Before modifying any sheet, a timestamped CSV backup is saved to `classifier/backups/`. Restore manually if needed.

## Troubleshooting

**"Preflight check failed"**
- Ensure Google APIs are enabled
- Ensure spreadsheet is shared with service account
- Run `dbt run --select fact_bank_transactions`

**"No staging SQL file found"**
- Sheet name must match SQL filename (e.g., `sg_sgd_dbs` → `stg_bank_sg_sgd_dbs.sql`)

**Predictions look wrong**
- Run with `--dry-run` to inspect confidence scores
- Raise threshold in `config.yml`
- Check that training data has good labels

## Architecture

```
classifier/
├── __init__.py              # Package marker
├── cli.py                   # Entry point (main orchestrator)
├── classify.py              # Convenience script wrapper
├── bigquery_client.py       # Load training data from BigQuery
├── sheets_client.py         # Read/write Google Sheets via gspread
├── model.py                 # sklearn pipeline + cross-validation
├── sql_parser.py            # Parse staging SQL with sqlglot
├── config.yml               # Configuration (BQ, Sheets, model params)
├── backups/                 # Timestamped CSV backups (auto-created)
├── README.md                # This file
└── SETUP.md                 # One-time setup checklist
```
