from google.oauth2 import service_account
from google.cloud import bigquery
import pandas as pd

SCOPES = ["https://www.googleapis.com/auth/bigquery"]


def load_training_data(
    project: str, dataset: str, table: str, keyfile: str
) -> pd.DataFrame:
    """
    Load labelled transactions from BigQuery for model training.

    Returns DataFrame with columns: description, local_amount, category.
    Only rows with non-null, non-empty category are returned.
    """
    credentials = service_account.Credentials.from_service_account_file(
        keyfile, scopes=SCOPES
    )
    client = bigquery.Client(project=project, credentials=credentials)

    query = f"""
        SELECT description, local_amount, category
        FROM `{project}.{dataset}.{table}`
        WHERE category IS NOT NULL AND TRIM(category) != ''
    """

    df = client.query(query).to_dataframe()
    return df
