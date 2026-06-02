#!/usr/bin/env python3
"""
cli.py — Predict blank categories in Google Sheets using BigQuery training data.

Usage:
    python -m classifier.cli                        # use default config.yml
    python -m classifier.cli --config path/to.yml  # custom config
    python -m classifier.cli --dry-run             # predict but don't write back
    python -m classifier.cli --sheet sg_sgd_dbs    # single sheet only
"""

import argparse
import logging
import sys
from pathlib import Path

import pandas as pd
import yaml

from .bigquery_client import load_training_data
from .model import predict_with_confidence, train
from .sheets_client import (
    backup_sheet,
    get_blank_category_rows,
    get_client,
    write_predictions,
)
from .sql_parser import (
    extract_description_columns,
    get_description_expression,
    evaluate_description_expression,
)

logger = logging.getLogger(__name__)


def load_config(path: str) -> dict:
    """Load YAML config file."""
    with open(path) as f:
        return yaml.safe_load(f)


def get_staging_sql_path(sheet_name: str) -> Path:
    """Construct the path to the staging SQL file for a given sheet name."""
    # Find the dbt directory relative to the classifier directory (parent/parent)
    repo_root = Path(__file__).parent.parent
    return (
        repo_root
        / "dbt"
        / "models"
        / "staging"
        / "bank"
        / "gsheet"
        / f"stg_bank_{sheet_name}.sql"
    )


def get_description_columns(sheet_name: str) -> list[str]:
    """
    Extract description column names for a sheet by parsing its staging SQL file.

    Raises ValueError if the file doesn't exist or parsing fails.
    """
    sql_path = get_staging_sql_path(sheet_name)
    if not sql_path.exists():
        raise FileNotFoundError(f"Staging SQL file not found: {sql_path}")

    with open(sql_path) as f:
        sql_text = f.read()

    return extract_description_columns(sql_text)


def run_preflight_checks(cfg: dict, sheet_names: list[str]) -> None:
    """
    Run preflight checks. Raises an exception if any check fails.

    Checks:
    1. BigQuery connectivity and table existence
    2. Google Sheets API access
    3. Staging SQL file existence for each sheet
    4. Description column extraction succeeds for each sheet
    """
    logger.info("=== Preflight Checks ===")

    bq_cfg = cfg["bigquery"]
    sheets_cfg = cfg["google_sheets"]

    # 1. BigQuery
    logger.info("1. Testing BigQuery connection...")
    try:
        df = load_training_data(
            project=bq_cfg["project"],
            dataset=bq_cfg["dataset"],
            table=bq_cfg["table"],
            keyfile=bq_cfg["keyfile"],
        )
        logger.info(f"✓ Connected. Table has {len(df)} labelled rows.")
    except Exception as e:
        raise RuntimeError(f"BigQuery preflight failed: {e}")

    # 2. Google Sheets API
    logger.info("2. Testing Google Sheets API access...")
    try:
        gc = get_client(sheets_cfg["keyfile"])
        spreadsheet = gc.open_by_key(sheets_cfg["spreadsheet_id"])
        logger.info(f"✓ Spreadsheet opened: {spreadsheet.title}")
    except PermissionError as e:
        # Check if it's the "API not enabled" error
        # The actual error is in the __cause__ chain
        error_str = str(e)
        cause_str = str(e.__cause__) if e.__cause__ else ""
        full_error = error_str + " " + cause_str

        if "Google Sheets API" in full_error and "not been used" in full_error:
            raise RuntimeError(
                "❌ Google Sheets API is DISABLED in your GCP project.\n\n"
                "FIX:\n"
                "  1. Go to: https://console.cloud.google.com/apis/api/sheets.googleapis.com/overview?project=jeremy-chia\n"
                "  2. Click: ENABLE\n"
                "  3. Also enable Google Drive API: https://console.cloud.google.com/apis/api/drive.googleapis.com/overview?project=jeremy-chia\n"
                "  4. Wait 1-2 minutes for changes to propagate\n"
                "  5. Try again: uv run python -m classifier.cli --sheet de_eur_n26 --dry-run"
            ) from e
        else:
            raise RuntimeError(
                f"Google Sheets API permission denied.\n\n"
                f"VERIFY:\n"
                f"  1. Spreadsheet is shared with: jeremy-chia@jeremy-chia.iam.gserviceaccount.com\n"
                f"  2. The account has Editor (not just Viewer) access\n"
                f"  3. Regenerate keys/keyfile.json from GCP service account keys\n"
                f"\nOriginal error: {e}"
            ) from e
    except Exception as e:
        raise RuntimeError(
            f"Google Sheets API access failed: {e}\n\n"
            f"VERIFY:\n"
            f"  1. Spreadsheet ID is correct: {sheets_cfg['spreadsheet_id']}\n"
            f"  2. Google Sheets API is enabled\n"
            f"  3. Google Drive API is enabled\n"
            f"  4. The spreadsheet is shared with the service account"
        ) from e

    # 3. Staging SQL files and description columns
    logger.info("3. Checking staging SQL files and description columns...")
    for sheet_name in sheet_names:
        try:
            cols = get_description_columns(sheet_name)
            logger.info(f"✓ {sheet_name}: description columns = {cols}")
        except FileNotFoundError as e:
            raise FileNotFoundError(
                f"Staging SQL preflight failed for {sheet_name}: {e}"
            )
        except Exception as e:
            raise ValueError(
                f"Description column extraction failed for {sheet_name}: {e}"
            )

    logger.info("✓ All preflight checks passed.")


def main():
    # Setup logging with pretty formatting
    class ColoredFormatter(logging.Formatter):
        """Custom formatter with colors, timestamps, and emojis."""

        COLORS = {
            "DEBUG": "\033[90m",  # Gray
            "INFO": "\033[94m",  # Blue
            "WARNING": "\033[93m",  # Yellow
            "ERROR": "\033[91m",  # Red
            "SUCCESS": "\033[92m",  # Green
        }
        RESET = "\033[0m"

        def format(self, record):
            level = record.levelname
            color = self.COLORS.get(level, self.RESET)
            timestamp = self.formatTime(record, datefmt="%H:%M:%S")

            emoji = {
                "DEBUG": "🔍",
                "INFO": "ℹ️",
                "WARNING": "⚠️",
                "ERROR": "❌",
            }.get(level, "")

            if emoji:
                msg = f"{emoji}  {record.msg}"
            else:
                msg = record.msg

            return f"{color}[{timestamp}] {msg}{self.RESET}"

    handler = logging.StreamHandler()
    handler.setFormatter(ColoredFormatter())

    # Configure root logger to show only INFO and above (suppress library DEBUG logs)
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.handlers = [handler]

    # Set our classifier modules to DEBUG to show internal details
    for module in [
        "classifier.model",
        "classifier.bigquery_client",
        "classifier.sheets_client",
        "classifier.sql_parser",
    ]:
        logging.getLogger(module).setLevel(logging.DEBUG)

    parser = argparse.ArgumentParser(
        description="Classify blank categories in bank transaction sheets"
    )
    parser.add_argument(
        "--config",
        default="classifier/config.yml",
        help="Path to config file (default: classifier/config.yml)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print predictions without writing to sheets",
    )
    parser.add_argument(
        "--sheet",
        help="Process a single sheet only (by name)",
    )
    args = parser.parse_args()

    cfg = load_config(args.config)
    bq_cfg = cfg["bigquery"]
    sheets_cfg = cfg["google_sheets"]
    clf_cfg = cfg["classifier"]

    threshold = clf_cfg["confidence_threshold"]
    backup_dir = clf_cfg["backup_dir"]

    sheet_names = sheets_cfg.get("sheets", [])
    if args.sheet:
        sheet_names = [args.sheet]

    # --- Preflight checks ---
    try:
        run_preflight_checks(cfg, sheet_names)
    except Exception as e:
        logger.error(f"Preflight check failed: {e}")
        sys.exit(1)

    # --- Load training data ---
    logger.info("Loading training data from BigQuery...")
    train_df = load_training_data(
        project=bq_cfg["project"],
        dataset=bq_cfg["dataset"],
        table=bq_cfg["table"],
        keyfile=bq_cfg["keyfile"],
    )
    logger.info(
        f"{len(train_df)} labelled rows, {train_df['category'].nunique()} categories"
    )

    # --- Train model ---
    logger.info("Training classifier (with cross-validation)...")
    pipeline = train(train_df, verbose=True)

    # --- Process each sheet ---
    gc = get_client(sheets_cfg["keyfile"])
    spreadsheet = gc.open_by_key(sheets_cfg["spreadsheet_id"])

    total_written = 0
    all_predictions = []  # For dry-run CSV export
    for sheet_name in sheet_names:
        logger.info(f"Processing sheet: {sheet_name}")
        try:
            ws = spreadsheet.worksheet(sheet_name)
        except Exception as e:
            logger.error(f"Could not open worksheet: {e}")
            continue

        # Get blank category rows and preserve original header order
        try:
            blank_rows, cat_col, row_nums = get_blank_category_rows(ws)
            # Get the original header order from the sheet
            original_headers = ws.row_values(1)
        except KeyError as e:
            logger.error(str(e))
            continue

        if not blank_rows:
            logger.info("No blank category rows — skipping.")
            continue

        logger.info(f"{len(blank_rows)} blank rows found")

        # Get staging SQL to derive description using the same logic as dbt
        try:
            sql_path = get_staging_sql_path(sheet_name)
            with open(sql_path) as f:
                staging_sql = f.read()
        except Exception as e:
            logger.error(f"Failed to read staging SQL: {e}")
            continue

        # Build inference DataFrame
        infer_df = pd.DataFrame(blank_rows)

        # Compute description using the SQL expression from the staging model
        try:
            infer_df["description"] = infer_df.apply(
                lambda row: evaluate_description_expression(staging_sql, row.to_dict()),
                axis=1,
            )
        except Exception as e:
            logger.warning(f"Failed to evaluate description expression: {e}")
            logger.info("Falling back to concatenating description columns")
            # Fallback: try to get description columns and concatenate
            try:
                desc_cols = get_description_columns(sheet_name)
                desc_values = []
                for desc_col in desc_cols:
                    if desc_col in infer_df.columns:
                        desc_values.append(infer_df[desc_col].fillna("").astype(str))
                    else:
                        desc_values.append(pd.Series([""] * len(infer_df)))

                if desc_values:
                    infer_df["description"] = desc_values[0].str.lower().str.strip()
                    for col_series in desc_values[1:]:
                        infer_df["description"] = (
                            infer_df["description"]
                            + " "
                            + col_series.str.lower().str.strip()
                        )
                    infer_df["description"] = infer_df["description"].str.strip()
                else:
                    infer_df["description"] = ""
            except Exception as fallback_e:
                logger.error(f"Failed to build description: {fallback_e}")
                continue

        # Get amount
        if "local_amount" not in infer_df.columns:
            # Try to find amount-like columns
            amt_candidates = [
                c
                for c in infer_df.columns
                if "amount" in c.lower()
                or "debit" in c.lower()
                or "credit" in c.lower()
            ]
            if amt_candidates:
                infer_df["local_amount"] = pd.to_numeric(
                    infer_df[amt_candidates[0]], errors="coerce"
                ).fillna(0)
            else:
                infer_df["local_amount"] = 0.0
        else:
            infer_df["local_amount"] = pd.to_numeric(
                infer_df["local_amount"], errors="coerce"
            ).fillna(0)

        # Predict
        result_df = predict_with_confidence(pipeline, infer_df)
        high_conf = result_df[result_df["confidence"] >= threshold]

        print(
            f"  {len(high_conf)}/{len(result_df)} predictions above threshold {threshold}"
        )

        if args.dry_run:
            # Collect all predictions (high + low confidence)
            for idx, (_, r) in enumerate(result_df.iterrows()):
                desc_preview = str(r.get("description", ""))[:60]
                confidence_str = f"{r['confidence']:.2f}"
                meets_threshold = r["confidence"] >= threshold
                flag = "✓" if meets_threshold else "✗"
                print(
                    f"    {flag} [{confidence_str}] {desc_preview} → {r['predicted_category']}"
                )
                # Store for CSV export with columns in original sheet order
                prediction_record = {}

                # Add metadata columns first
                prediction_record["predicted_category"] = r["predicted_category"]
                prediction_record["confidence"] = f"{r['confidence']:.4f}"
                prediction_record["will_write"] = "YES" if meets_threshold else "NO"

                # Add all original sheet columns in their ORIGINAL SHEET ORDER
                # (use original_headers which preserves the sheet's column order)
                for header_name in original_headers:
                    # Handle case-insensitive matching since gspread lowercases keys
                    col_key = next(
                        (k for k in r.keys() if k.lower() == header_name.lower()), None
                    )
                    if col_key:
                        prediction_record[header_name] = r.get(col_key, "")
                    else:
                        prediction_record[header_name] = ""

                # Add description and local_amount at the end for debugging
                prediction_record["_description_computed"] = r.get("description", "")
                prediction_record["_local_amount"] = r.get("local_amount", "")

                all_predictions.append(prediction_record)
            print()
            continue

        # Backup before writing
        backup_sheet(ws, backup_dir)

        # Write only high-confidence rows back
        if len(high_conf) > 0:
            high_conf_indices = high_conf.index.tolist()
            selected_row_nums = [row_nums[i] for i in high_conf_indices]
            n = write_predictions(
                ws,
                selected_row_nums,
                cat_col,
                high_conf["predicted_category"].tolist(),
            )
            logger.info(f"Wrote {n} predictions to sheet")
            total_written += n

    # Save dry-run results to CSV
    if args.dry_run and all_predictions:
        from datetime import datetime
        import os

        ts = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        # Save alongside backups directory
        os.makedirs(backup_dir, exist_ok=True)
        dry_run_path = os.path.join(backup_dir, f"dry_run_{ts}.csv")
        pred_df = pd.DataFrame(all_predictions)
        pred_df.to_csv(dry_run_path, index=False)
        logger.info(f"Dry-run results saved to: {dry_run_path}")

    logger.info(f"Done. Total cells updated: {total_written}")


if __name__ == "__main__":
    main()
