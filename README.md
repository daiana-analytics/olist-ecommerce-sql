# olist-ecommerce-sql

**SQL Server project for the Olist e-commerce dataset.**
End-to-end pipeline **RAW → CLEAN → QUALITY → BI** with reproducible scripts, safe quality views, a model snapshot, and portfolio-ready screenshots. **Power BI-ready.**

---

## Table of Contents

* [What It Is](#what-it-is)
* [Architecture](#architecture)
* [Repository Structure](#repository-structure)
* [Quick Start](#quick-start)
* [Execution Order](#execution-order)
* [Outputs](#outputs)
* [Screenshots](#screenshots)
* [Skills Demonstrated](#skills-demonstrated)
* [Data & License](#data--license)

---

## What It Is

Production-style project that loads the public Olist dataset, normalizes it, **validates data quality** with canonical order-cycle rules, and **publishes BI-ready views**.
All DDL uses `CREATE OR ALTER` → **idempotent** and safe to re-run. The pipeline is **non-destructive** (it does not modify `clean.*` tables).

---

## Architecture

```text
CSV  →  01_raw   →   02_clean     →     99_quality      →      03_bi      →  Power BI
         └─ bulk load  └─ transforms   └─ checks + views   └─ business views (bi.*)
```

---

## Repository Structure

```text
sql_server/
  00_environment/           # DB + schemas + model snapshot
  01_raw/                   # RAW tables + bulk-load scripts
  02_clean/                 # CLEAN tables + transforms
  99_quality/               # Data-quality checks + quality.* views
  03_bi/                    # BI views + README queries + screenshots
docs/                       # Documentation (placeholders)
LICENSE
```

**Key READMEs**

* Quality layer → `sql_server/99_quality/README.md`
* BI layer → `sql_server/03_bi/README.md`

---

## Quick Start

### Requirements

* SQL Server 2019+ (or Azure SQL DB).
* Database `olist_sqlsrv` created.
* Olist CSVs downloaded locally (RAW layer reads your local files; they are not versioned in the repo).

### How to Run

Open the repo in **SSMS** or **Azure Data Studio**.

In each session start with:

```sql
USE olist_sqlsrv;
GO
```

Run the scripts in the order below. Update the `BULK` file paths in the RAW layer to your CSV locations.

---

## Execution Order

**Environment →** `sql_server/00_environment/*`
Creates DB, schemas, and the model snapshot.

**RAW →** `sql_server/01_raw/*`
Creates RAW tables + bulk-loads CSVs.

**CLEAN →** `sql_server/02_clean/*`
Types, de-duplicates, and applies constraints/FKs.

**QUALITY →** `sql_server/99_quality/99c_quality_fixes.sql`
Publishes `quality.*` views.
Optional: `99a` sanity checks, `99b` deep checks, `99d` KPIs/reconciliation.

**BI →** `sql_server/03_bi/03a_publish_bi_views.sql`
Publishes `bi.*` views.
Optional: `03c` extra views; `03b/03d` reproduce screenshots.

---

## Outputs

### Quality Views (`quality.*`)

Examples:

* `invalid_orders_time_logic`, `invalid_orders_summary`, `valid_orders`
* `order_items_valid`, `payments_valid`, `orders_quality_snapshot`
  ➡ See **QUALITY README**.

### BI Views (`bi.*`)

Examples:

* `v_kpi_summary`, `v_daily_sales`, `v_payment_mix`, `v_delivery_lead_time`
* `v_state_lead_time`, `v_category_sales_monthly`, `v_repeat_customers`
  ➡ See **BI README**.

---

## Screenshots

### QUALITY

* Quality snapshot → `readme_04_quality_snapshot.png`
* See all → `sql_server/99_quality/screenshots/`

### BI

* KPI summary → `readme_06_bi_kpi_summary.png`
* Daily sales → `readme_07_bi_daily_sales.png`
* Payment mix → `readme_08_bi_payment_mix.png`
* Late orders → `readme_09_bi_late_orders.png`
* Lead-time dist. → `readme_10_bi_lead_time_dist.png`
* Category × month → `readme_11_bi_category_monthly.png`
* Lead time by state → `readme_12_bi_state_lead_time.png`
* Repeat customers → `readme_13_bi_repeat_customers.png`
* See all → `sql_server/03_bi/screenshots/`

---

## Skills Demonstrated

* **SQL Server:** DDL/DML, window functions, `CREATE OR ALTER VIEW`, constraints/FKs, idempotent scripting
* **Modeling:** RAW → CLEAN normalization; canonical order-cycle rules
* **Data Quality:** non-destructive checks, safe `quality.*` views, reconciliation KPIs
* **Analytics Engineering:** BI views ready for Power BI (daily sales, payment mix, delays, lead time, categories, repeat behavior)
* **Reproducibility & Docs:** deterministic run order, per-module READMEs, evidence via screenshots

---

## Data & License

* **Dataset:** Olist e-commerce (public: orders, items, payments, products, customers)
* **Usage:** SQL for portfolio/demo purposes; the dataset belongs to its original authors
* **License:** see **MIT**
