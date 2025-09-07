# 99 — Data Quality (SQL Server)

**Goal.** Validate the dataset **before** BI so downstream views/reports are trustworthy.  
**Non-destructive.** Does **not** modify `clean.*`; publishes views under `quality.*` using `CREATE OR ALTER` (idempotent).

## Scripts (run order)
1. **99a_quality_checks.sql** — sanity checks (row counts, nulls, PK/FK/orphans, date ranges)  
2. **99b_quality_deep_checks.sql** — domain rules (payments vs orders, negatives, duplicates)  
3. **(Optional) 99c_quality_fixes.sql** — publishes `quality.*` views  
4. **99d_quality_sanity_checks.sql** — sanity KPIs & reconciliation

## Views published by `99c_quality_fixes.sql` *(schema `quality`)*
- `invalid_orders_time_logic` — one row per time-logic violation  
- `invalid_orders_ids` — distinct `order_id` with any violation  
- `invalid_orders_summary` — counts per violation code/description  
- `valid_orders` — `clean.orders` minus violating orders  
- `order_items_valid` — items scoped to valid orders  
- `payments_valid` — payments scoped to valid orders  
- `orders_repaired` *(optional)* — repaired timestamps without mutating `clean.*`  
- `orders_quality_snapshot` — single-row KPIs (totals, valid, invalid, ratio)

## Time-logic rules (canonical)
- **T1:** `approved_at` ≥ `purchase_timestamp`  
- **T2:** `carrier_date` ≥ `approved_at`  
- **T3:** `customer_date` ≥ `carrier_date`  
- **T4:** `customer_date` ≥ `purchase_timestamp`

## Evidence (screenshots)
All screenshots are included for reproducibility and audit (folder `./screenshots/`):

- **Sanity checks OK:**  
  [readme_01_quality_checks_pass.png](./screenshots/readme_01_quality_checks_pass.png)
- **Views published (idempotent):**  
  [readme_02_quality_fixes_published.png](./screenshots/readme_02_quality_fixes_published.png)
- **Sanity KPIs & reconciliation:**  
  [readme_03_sanity_checks_results.png](./screenshots/readme_03_sanity_checks_results.png)
- **Quality snapshot (totals, valid, invalid, ratio):**  
  [readme_04_quality_snapshot.png](./screenshots/readme_04_quality_snapshot.png)
- **Published views (`quality.*` / `bi.*`):**  
  [readme_05_published_views.png](./screenshots/readme_05_published_views.png)

**Supporting material (model & deep checks):**  
[readme_00_model_clean.png](./screenshots/readme_00_model_clean.png) •
[readme_00_model_clean_keys.png](./screenshots/readme_00_model_clean_keys.png) •
[readme_00a_deep_checks_dups_nulls.png](./screenshots/readme_00a_deep_checks_dups_nulls.png) •
[readme_00b_deep_checks_payment_fk.png](./screenshots/readme_00b_deep_checks_payment_fk.png)

## Quick notes
- **Reproducible & idempotent** — safe to re-run  
- Naming style: `lower_snake_case`  
- **Recommended inputs for BI:** `quality.valid_orders`, `quality.order_items_valid`, `quality.payments_valid`

---

*Dataset: Olist e-commerce (public). SQL provided for portfolio/demo purposes; dataset ownership remains with the original authors.*
