/sql_server/99_quality — Data Quality (SQL Server)

Goal. Validate the dataset before BI so downstream views/reports are trustworthy.
Non-destructive. Scripts do not modify clean.* tables. The final layer publishes views under quality.* using CREATE OR ALTER (idempotent).

Prerequisites

SQL Server 2019+ (or Azure SQL DB).

Database olist_sqlsrv with source tables in schema clean.

Run after /00_environment, /01_raw, /02_clean and before /03_bi.

Use this header in each session: 
USE olist_sqlsrv;
GO

Folder structure
99_quality/
├─ 99a_quality_checks.sql           -- sanity checks (row counts, nulls, PK/FK/orphans, date ranges)
├─ 99b_quality_deep_checks.sql      -- domain rules (payments vs orders, negatives, duplicates)
├─ 99c_quality_fixes.sql            -- publishes quality-safe views (CREATE OR ALTER VIEW)
├─ 99d_quality_sanity_checks.sql    -- quick KPIs & verification queries
└─ screenshots/                     -- evidence (ERD and check results)

Run order

99a_quality_checks.sql

99b_quality_deep_checks.sql

(Optional) 99c_quality_fixes.sql — publishes quality.* views

99d_quality_sanity_checks.sql — sanity KPIs & reconciliation

Views published by 99c_quality_fixes.sql (all under schema quality)

invalid_orders_time_logic — one row per violation.

invalid_orders_ids — distinct order_id failing rules.

invalid_orders_summary — counts per violation code/description.

valid_orders — clean.orders minus violating orders.

order_items_valid — items scoped to valid orders.

payments_valid — payments scoped to valid orders.

orders_repaired (optional) — non-destructive fixed timestamps.

orders_quality_snapshot — single-row KPIs (totals, ratios).

Time-logic rules (canonical expectations)

T1: approved_at ≥ purchase_timestamp

T2: carrier_date ≥ approved_at

T3: customer_date ≥ carrier_date

T4: customer_date ≥ purchase_timestamp

Outputs & evidence

Save screenshots to: /sql_server/99_quality/screenshots/.

(Optional) Persist results to tables like: quality.check_results, quality.sanity_results.

Conventions

Idempotent where possible; safe to re-run.

lower_snake_case naming.

Keep checks read-only; fixes are published as views.

Troubleshooting

Red squiggles / “Invalid column name” in SSMS → Ctrl+Shift+R (refresh IntelliSense).

Permissions: ensure CREATE VIEW on schema quality.

Wrong DB: verify the USE olist_sqlsrv; GO header.

Data source & license

Olist e-commerce public dataset (orders, items, payments, products, customers).
SQL provided for portfolio/demo purposes; dataset ownership remains with original authors.
