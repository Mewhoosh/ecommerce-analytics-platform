# E-commerce Analytics Platform

End-to-end analytics project on the **Brazilian E-Commerce (Olist)** dataset — from raw CSVs to a Power BI dashboard, with a relational data model, Python ETL, and analytical SQL in between.

<img width="1320" height="740" alt="obraz" src="https://github.com/user-attachments/assets/95fd70a2-7735-40d1-81b4-582e25f3b843" />


---

## What's inside

- **8-table relational schema** in PostgreSQL with proper PKs, FKs, CHECK constraints, and indexes
- **Python data loader** (pandas + SQLAlchemy) with type coercion, deduplication, and post-load validation
- **8 analytical SQL queries** covering revenue trends, customer LTV, RFM segmentation, delivery KPIs, and cohort retention
- **8 reporting views** that pre-aggregate logic for the BI layer
- **Power BI dashboard** with four pages: Executive Overview, Customer Analytics, Products & Categories, Operations & Logistics

## Tech stack

| Layer | Tools |
|-------|-------|
| Storage | PostgreSQL 16 (Docker) |
| ETL | Python 3.11, pandas, SQLAlchemy |
| Modeling | SQL — CTEs, window functions, materialized logic in views |
| BI | Power BI Desktop (DAX measures, star-like model) |
| Infra | Docker Compose |

## Architecture

```
 CSV (Kaggle)  ──►  Python loader  ──►  PostgreSQL  ──►  Views  ──►  Power BI
                    (pandas,             (8 tables,      (8 views    (4-page
                     validation)         FKs, indexes)    for BI)     dashboard)
```

## Key business insights

Findings surfaced by the SQL/BI layer:

1. **Black Friday spike** — November 2017 generated peak monthly revenue (~1.16M BRL), with a sharp drop in December (standard post-BF seasonality).
2. **RJ paradox** — Rio de Janeiro is the **2nd-largest state by revenue** (~2M BRL) but ranks **#8 worst** for on-time delivery (87.79%). Not a geography problem (Rio is well-connected) — it's an **operational logistics issue** worth prioritizing.
3. **Low repeat rate** — only **~3%** of customers return for a second order. This is an acquisition-heavy business; retention is the open lever.
4. **At Risk paradox** — the *At Risk* RFM segment has the same average CLV (~308 BRL) as *Champions* (~310 BRL). These customers were top spenders but went silent. **Win-back ROI > new acquisition ROI** for this segment.
5. **Top spenders are mostly At Risk** — 8 of the top 10 customers by lifetime value haven't ordered in over a year. The single biggest spender (13,664 BRL CLV) is 383 days silent.
6. **Long-tail CLV** — ~85% of customers spend under 200 BRL; a thin tail of high-value customers up to 14k BRL. Classic Pareto — justifies segment-specific marketing rather than one-size-fits-all.
7. **Operations recovered from BF peak** — on-time delivery dropped from ~100% (low-volume 2016) to ~80% around Black Friday 2017 as orders spiked, then climbed back to ~92% in 2018 — a clear story of operational scaling.
8. **Seller concentration** — top 10 sellers (0.3% of the supply base) generate ~10% of order volume; 9 of them are based in São Paulo, mirroring the demand-side concentration.
9. **Brazilian payment mix** — credit card 74%, boleto (bank slip) 19%, voucher 5%, debit card 2%. Boleto is a local-market signal often missed in generic e-commerce templates.

## Dashboard preview

### Executive Overview

<img width="1320" height="740" alt="obraz" src="https://github.com/user-attachments/assets/2e908de2-fa7d-4ab1-bfd8-2e45378ecdb2" />


KPI snapshot, monthly revenue trend, worst-performing delivery states, customer segment distribution, and revenue concentration by state.

### Customer Analytics

<img width="1308" height="729" alt="obraz" src="https://github.com/user-attachments/assets/a5d71412-d164-4799-b9cc-4b70b6584646" />


Segment-level deep dive: customer counts and average CLV per segment, top spenders table, and CLV distribution (whales filtered for readability).

### Products & Categories

<img width="1312" height="735" alt="obraz" src="https://github.com/user-attachments/assets/bb0b1de1-5dd4-4432-8cb3-a9ea4a39fdc1" />


Category treemap, top categories by revenue and by average item value — surfaces both volume leaders (health_beauty, watches_gifts) and high-ticket niches (computers).

### Operations & Logistics

<img width="1308" height="730" alt="obraz" src="https://github.com/user-attachments/assets/9a5ca24a-fee5-4c35-9ae7-dbba44556d87" />


Delivery time histogram, on-time delivery trend over time, payment method breakdown (incl. Brazilian boleto), and top sellers table.

## How to run

### Prerequisites
- Docker Desktop
- Python 3.11+
- DBeaver (or any PostgreSQL client)
- Power BI Desktop (Windows-only)
- Olist dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) extracted into `data/raw/`

### Steps

```bash
# 1. Start Postgres
docker compose up -d

# 2. Install Python deps
python -m venv .venv
.venv\Scripts\Activate.ps1        # PowerShell
pip install -r requirements.txt

# 3. Create schema in DBeaver
#    Run sql/schema/01_create_schema.sql against the database

# 4. Load data
python scripts/load_data.py

# 5. Create reporting views
#    Run sql/views/01_create_views.sql
#    Run sql/views/02_create_views_extra.sql

# 6. Open powerbi/dashboard.pbix in Power BI Desktop
#    Refresh data — the dashboard connects to localhost:5432
```

## Project structure

```
ecommerce-analytics-platform/
├── data/raw/                       # Olist CSVs (not committed)
├── docker-compose.yml              # Postgres in Docker
├── scripts/
│   └── load_data.py                # CSV -> Postgres ETL
├── sql/
│   ├── schema/01_create_schema.sql      # 8 tables, FKs, indexes
│   ├── views/01_create_views.sql        # 4 core reporting views
│   ├── views/02_create_views_extra.sql  # 4 views for products and operations pages
│   └── analyses/                        # 8 standalone analytical queries
│       ├── 01_monthly_revenue_trend.sql
│       ├── 02_revenue_by_category.sql
│       ├── 03_top_customers.sql
│       ├── 04_customer_lifetime_value.sql
│       ├── 05_top_products_per_category.sql
│       ├── 06_delivery_performance.sql
│       ├── 07_rfm_segmentation.sql
│       └── 08_cohort_retention.sql
├── powerbi/
│   └── dashboard.pbix              # Four-page Power BI report
├── requirements.txt
└── README.md
```

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100k orders placed between September 2016 and September 2018, spanning 9 related tables (orders, customers, items, payments, reviews, products, sellers, geolocation, category translations).
