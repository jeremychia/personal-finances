# Service Account Setup for Classifier

This guide explains how to set up the service account that the classifier uses to access BigQuery and Google Sheets.

## What the Classifier Needs

The classifier requires a Google Cloud **service account** with:

1. **BigQuery Admin** role (or BigQuery Data Viewer minimum) — to read training data from BigQuery
2. **Editor** access to the target Google Spreadsheet — to read and write sheet data

The service account credentials must be stored as a JSON keyfile at `keys/keyfile.json`.

## Setup Instructions (Generic)

### Step 1: Create or Identify the Service Account

You need a Google Cloud service account. If you don't have one:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Navigate to **IAM & Admin** → **Service Accounts**
4. Click **Create Service Account**
5. Give it a name (e.g., `classifier`, `finance-bot`, etc.)
6. Click **Create and Continue**

Once you have a service account, note its email address (e.g., `my-service-account@my-project.iam.gserviceaccount.com`).

### Step 2: Grant BigQuery Permissions

1. In [Google Cloud Console](https://console.cloud.google.com), go to **IAM & Admin** → **IAM**
2. Find your service account in the list
3. Click **Edit** (pencil icon)
4. Click **Add Another Role**
5. Search for and select **BigQuery Admin** (`roles/bigquery.admin`)
   - Alternative: **BigQuery Data Viewer** (`roles/bigquery.dataViewer`) if you only need read access
6. Click **Save**

### Step 3: Grant Google Sheets Access

1. Open the target Google Spreadsheet
2. Click **Share** (top right)
3. Enter the service account email from Step 1
4. Set permissions to **Editor**
5. Click **Share**

### Step 4: Generate and Save the JSON Keyfile

1. Go to [Google Cloud Console](https://console.cloud.google.com) → **IAM & Admin** → **Service Accounts**
2. Click your service account
3. Go to the **Keys** tab
4. Click **Add Key** → **Create new key**
5. Select **JSON** format
6. Click **Create**
7. A JSON file will download automatically
8. Move this file to `keys/keyfile.json` in your project root

**Important:** Keep this keyfile secure. It contains credentials that grant access to your cloud resources.

### Step 5: Verify the Setup

Run the preflight checks:

```bash
uv run python -m classifier.cli --sheet <any_sheet_name> --dry-run
```

Replace `<any_sheet_name>` with a sheet tab name from your spreadsheet (e.g., `de_eur_n26`, `sg_sgd_dbs`).

You should see:
```
=== Preflight Checks ===

1. Testing BigQuery connection...
   ✓ Connected. Table has XXX labelled rows.

2. Testing Google Sheets API access...
   ✓ Spreadsheet opened: <Spreadsheet Name>

3. Checking staging SQL files and description columns...
   ✓ <sheet_name>: description columns = [...]

✓ All preflight checks passed.
```

If you see an error, check:

| Error | Solution |
|---|---|
| `ACCESS_TOKEN_SCOPE_INSUFFICIENT` | Regenerate the JSON keyfile — the current one was created before permissions were granted |
| `Could not authenticate` | Ensure the keyfile is at `keys/keyfile.json` and is valid JSON |
| `Spreadsheet not found` | Verify the spreadsheet is shared with the service account email |
| `Staging SQL file not found` | Ensure the sheet name matches a staging model filename |

## Configuration

Edit `classifier/config.yml` to point to:

- Your BigQuery project, dataset, and table containing training data
- Your Google Spreadsheet ID
- The confidence threshold for predictions
- Which sheet tabs to process

## Reference: Scopes Required

The JSON keyfile will automatically include these scopes when generated:

- `https://www.googleapis.com/auth/bigquery.readonly` — read BigQuery
- `https://www.googleapis.com/auth/spreadsheets` — read/write Google Sheets
- `https://www.googleapis.com/auth/drive.readonly` — access shared files

These are requested automatically based on the roles granted to the service account.
