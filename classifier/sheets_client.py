import csv
import os
from datetime import datetime
from google.oauth2 import service_account
import gspread

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
    "https://www.googleapis.com/auth/cloud-platform",
]


def get_client(keyfile: str) -> gspread.Client:
    """Authenticate to Google Sheets using service account."""
    try:
        creds = service_account.Credentials.from_service_account_file(
            keyfile, scopes=SCOPES
        )
        return gspread.authorize(creds)
    except FileNotFoundError:
        raise RuntimeError(
            f"Keyfile not found: {keyfile}\n\n"
            f"Please ensure the service account JSON keyfile exists at: {keyfile}"
        )
    except Exception as e:
        error_detail = f"{type(e).__name__}: {e}" if str(e) else type(e).__name__
        raise RuntimeError(
            f"Failed to authenticate with Google Sheets API.\n\n"
            f"Error: {error_detail}\n\n"
            f"LIKELY CAUSE:\n"
            f"The keyfile was created BEFORE you granted the service account access to Google Sheets.\n\n"
            f"REQUIRED FIX:\n"
            f"You must regenerate the keyfile with current permissions:\n"
            f"  1. Go to: https://console.cloud.google.com/iam-admin/serviceaccounts\n"
            f"  2. Click: jeremy-chia@jeremy-chia.iam.gserviceaccount.com\n"
            f"  3. Go to: Keys tab\n"
            f"  4. Click: Add Key → Create new key → JSON format\n"
            f"  5. Download the new key\n"
            f"  6. Replace keys/keyfile.json with the downloaded file\n\n"
            f"ALSO VERIFY:\n"
            f"  • The spreadsheet is shared with: jeremy-chia@jeremy-chia.iam.gserviceaccount.com\n"
            f"  • The service account has Editor access (not just Viewer)\n"
            f"  • Google Sheets API is enabled in your GCP project"
        ) from e


def backup_sheet(ws: gspread.Worksheet, backup_dir: str) -> str:
    """
    Export all sheet data to a timestamped CSV.

    Returns the file path.
    """
    os.makedirs(backup_dir, exist_ok=True)
    ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    path = os.path.join(backup_dir, f"{ts}_{ws.title}.csv")

    rows = ws.get_all_values()
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"  Backup saved: {path}")
    return path


def get_blank_category_rows(ws: gspread.Worksheet) -> tuple[list[dict], int, list[int]]:
    """
    Find rows where the category column is blank.

    Returns:
      records       - list of dicts for blank-category rows
      category_col  - 0-indexed column index of 'category'
      row_nums      - 1-indexed sheet row numbers for blank-category rows (for write-back)

    Raises KeyError if 'category' column is not found.
    """
    records = ws.get_all_records()  # uses row 1 as header (lowercased)
    header = ws.row_values(1)

    # Find category column (case-insensitive)
    try:
        cat_col = next(i for i, h in enumerate(header) if h.lower() == "category")
    except StopIteration:
        raise KeyError(f"Column 'category' not found. Headers: {header}")

    blank_records = []
    blank_row_nums = []

    for i, row in enumerate(records):
        # Find the category value using case-insensitive key matching
        cat_value = None
        for k, v in row.items():
            if k.lower() == "category":
                cat_value = v
                break

        val = str(cat_value if cat_value is not None else "").strip()
        if not val:
            blank_records.append(row)
            blank_row_nums.append(i + 2)  # +2: skip header row + convert to 1-indexed

    return blank_records, cat_col, blank_row_nums


def write_predictions(
    ws: gspread.Worksheet,
    row_nums: list[int],
    cat_col: int,
    predictions: list[str],
) -> int:
    """
    Batch-write predictions to the category column.

    Args:
      ws            - gspread Worksheet
      row_nums      - 1-indexed row numbers to update
      cat_col       - 0-indexed column index
      predictions   - list of category strings (must match length of row_nums)

    Returns the count of cells updated.
    """
    if not row_nums:
        return 0

    updates = []
    for row_num, pred in zip(row_nums, predictions):
        # Convert to A1 notation (e.g., "B42" for column 1, row 42)
        col_letter = gspread.utils.rowcol_to_a1(row_num, cat_col + 1).rstrip(
            "0123456789"
        )
        cell_ref = f"{col_letter}{row_num}"
        updates.append({"range": cell_ref, "values": [[pred]]})

    if updates:
        ws.spreadsheet.values_batch_update({"valueInputOption": "RAW", "data": updates})

    return len(updates)
