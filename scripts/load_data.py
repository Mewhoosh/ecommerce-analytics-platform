"""Load Olist CSV files into the PostgreSQL database.

Run from project root:
    python scripts/load_data.py

Assumes the schema (sql/schema/01_create_schema.sql) is already applied
and tables are empty.
"""

import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text


# Config -----------------------------------------------------------------------

load_dotenv()  # reads .env into os.environ

DATA_DIR = Path(__file__).parent.parent / "data" / "raw"

# SQLAlchemy URL format: postgresql+driver://user:pass@host:port/dbname
DB_URL = (
    f"postgresql+psycopg2://{os.environ['POSTGRES_USER']}:"
    f"{os.environ['POSTGRES_PASSWORD']}@{os.environ['POSTGRES_HOST']}:"
    f"{os.environ['POSTGRES_PORT']}/{os.environ['POSTGRES_DB']}"
)

engine = create_engine(DB_URL)


# Helpers ----------------------------------------------------------------------

def read_csv(filename: str) -> pd.DataFrame:
    return pd.read_csv(DATA_DIR / filename)


def load(df: pd.DataFrame, table: str) -> None:
    """Append a DataFrame to a Postgres table.

    method='multi' batches multiple rows per INSERT — much faster than
    one-row-at-a-time, which is the pandas default.
    """
    df.to_sql(
        table,
        engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=5000,
    )
    print(f"  {len(df):>7,} rows -> {table}")


# Per-table loaders ------------------------------------------------------------

def load_customers() -> None:
    df = read_csv("olist_customers_dataset.csv")
    # Zip prefix arrives as int (e.g. 1151). Brazilian CEP is 5 digits with
    # leading zeros — pad to preserve "01151".
    df["customer_zip_code_prefix"] = (
        df["customer_zip_code_prefix"].astype(str).str.zfill(5)
    )
    load(df, "customers")


def load_categories() -> None:
    df = read_csv("product_category_name_translation.csv")
    load(df, "product_category_translation")


def load_products() -> None:
    df = read_csv("olist_products_dataset.csv")
    # Source CSV has typos: "lenght" instead of "length". Fix on load so the
    # DB schema uses correct English.
    df = df.rename(columns={
        "product_name_lenght": "product_name_length",
        "product_description_lenght": "product_description_length",
    })
    load(df, "products")


def load_sellers() -> None:
    df = read_csv("olist_sellers_dataset.csv")
    df["seller_zip_code_prefix"] = (
        df["seller_zip_code_prefix"].astype(str).str.zfill(5)
    )
    load(df, "sellers")


def load_orders() -> None:
    df = read_csv("olist_orders_dataset.csv")
    # All five timestamps stored as strings in CSV. Parse to datetime;
    # errors='coerce' turns unparseable values into NaT (-> NULL in Postgres).
    date_cols = [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ]
    for col in date_cols:
        df[col] = pd.to_datetime(df[col], errors="coerce")
    load(df, "orders")


def load_order_items() -> None:
    df = read_csv("olist_order_items_dataset.csv")
    df["shipping_limit_date"] = pd.to_datetime(
        df["shipping_limit_date"], errors="coerce"
    )
    load(df, "order_items")


def load_order_payments() -> None:
    df = read_csv("olist_order_payments_dataset.csv")
    load(df, "order_payments")


def load_order_reviews() -> None:
    df = read_csv("olist_order_reviews_dataset.csv")
    # review_id alone is not unique (814 dupes). The composite (review_id,
    # order_id) IS unique — assert that, so the script fails loudly if the
    # source ever changes.
    dupes = df.duplicated(["review_id", "order_id"]).sum()
    assert dupes == 0, f"Found {dupes} duplicate (review_id, order_id) pairs"

    for col in ["review_creation_date", "review_answer_timestamp"]:
        df[col] = pd.to_datetime(df[col], errors="coerce")
    load(df, "order_reviews")


# Verification -----------------------------------------------------------------

EXPECTED_TABLES = [
    "customers",
    "product_category_translation",
    "products",
    "sellers",
    "orders",
    "order_items",
    "order_payments",
    "order_reviews",
]


def verify() -> None:
    print("\nRow counts in DB:")
    with engine.connect() as conn:
        for tbl in EXPECTED_TABLES:
            n = conn.execute(text(f"SELECT COUNT(*) FROM {tbl}")).scalar()
            print(f"  {tbl:<32} {n:>7,}")


# Orchestration ----------------------------------------------------------------

def main() -> None:
    print("Loading data into Postgres...")
    # Parents before children (FK dependency order).
    load_customers()
    load_categories()
    load_products()
    load_sellers()
    load_orders()
    load_order_items()
    load_order_payments()
    load_order_reviews()
    verify()


if __name__ == "__main__":
    main()
