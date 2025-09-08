# 01_raw — Ingestion layer (SQL Server)

**Purpose.** Create RAW tables and load data from staging (`dbo.*_dataset`) in an idempotent and safe way.

---

## What it does
- Creates RAW tables: `orders`, `order_items`, `payments`, `reviews`, `customers`, `sellers`.
- Completes the layer with: `geolocation`, `products`, `product_category_name_translation`.
- Loads from staging with type conversions, minimal deduplication, and transactional control.
- Adds helper indexes for BI-friendly reads.

---

## Scripts & order
| Order | Script | Description | Idempotent |
|-----:|:--|--|:--:|
| 01   | [01_create_raw_tables.sql](01_create_raw_tables.sql) | Create core RAW tables + PKs/indexes | Yes |
| 01b  | [01b_create_raw_tables_extra.sql](01b_create_raw_tables_extra.sql) | Create remaining RAW tables + indexes | Yes |
| 01c  | [01c_load_from_staging.sql](01c_load_from_staging.sql) | Load from `dbo.*_dataset` (transactional) | Yes |

---

## Prerequisites
- SQL Server 2019+ (or Azure SQL Database).
- SSMS or Azure Data Studio.
- Permissions to create database/schemas and run `CREATE TABLE`/`CREATE INDEX`.
- Staging tables (`dbo.*_dataset`) already loaded (Import Wizard or another process).

---

## How to run
```sql
USE olist_sqlsrv;
:r .\sql_server\01_raw\01_create_raw_tables.sql
:r .\sql_server\01_raw\01b_create_raw_tables_extra.sql
:r .\sql_server\01_raw\01c_load_from_staging.sql
```

### Inputs (staging)
- `dbo.olist_orders_dataset`
- `dbo.olist_order_items_dataset`
- `dbo.olist_order_payments_dataset`
- `dbo.olist_order_reviews_dataset`
- `dbo.olist_customers_dataset`
- `dbo.olist_sellers_dataset`
- `dbo.olist_geolocation_dataset`
- `dbo.olist_products_dataset`
- `dbo.product_category_name_translation` *(may arrive as `column1/column2` from Import Wizard)*

---

### Outputs (RAW)
- Tables in `raw.*` with **PKs** where applicable.  
- No FKs (typical *landing zone* design).

**Helper indexes**
- `IX_raw_orders_customer (customer_id)`
- `IX_raw_order_items_product (product_id)`
- `IX_raw_payments_type (payment_type)`
- `IX_raw_customers_unique (customer_unique_id)`
- `IX_raw_products_category (product_category_name)`
- `UX_raw_category_translation_pt (product_category_name)` — *unique*
- `IX_raw_geolocation_zip (geolocation_zip_code_prefix)`

---

### Idempotency & safety
- **Create-if-missing** for tables, PKs, and indexes.
- Loads use `INSERT … WHERE NOT EXISTS`.
- Data shaping with `TRY_CAST/TRY_CONVERT`; decimal fix via `REPLACE(',', '.')`.
- Per-block transactions with `SET XACT_ABORT ON` and `TRY/CATCH`.
- Optional local reset flags in `01c` (`@reset_all`, `@reset_reviews`) — keep defaults in repo.

---

### Quick QA
- `01c` ends with a **QUICK QA** section (row counts per table).
- For a full technical inventory (columns, PK/FK lists, dependencies), use the snapshot in `00_environment/00z_model_snapshot.sql`.

---

### Notes
- `raw.geolocation` has **no PK** (multiple rows per ZIP prefix).
- `raw.reviews` is **deduplicated by `review_id`** using `ROW_NUMBER()` (keeps latest).
- Category translation script renames `column1/column2` to expected names when necessary.

## Troubleshooting
- **Decimals with comma**: if `.csv` values use `,`, the scripts already apply `REPLACE(',', '.')`.
- **Category translation**: if Import Wizard created `column1/column2`, the script auto-renames to expected columns.
- **Local re-runs**: use `@reset_all` or `@reset_reviews` in `01c` for local resets (keep repo defaults).
- **Full inventory**: for columns/PK/FK/dependencies, use `00_environment/00z_model_snapshot.sql`.



