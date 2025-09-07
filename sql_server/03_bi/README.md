# 03 — BI Layer (SQL Server)

**Purpose.** Business-ready views built **only** from quality-safe data (`quality.*` from the 99 layer).  
**Non-destructive & idempotent.** Creates **views** under `bi.*` using `CREATE OR ALTER`.

## Scripts (run order)
1. `99_quality/99c_quality_fixes.sql` — publishes `quality.*` views  
2. **03a_publish_bi_views.sql** — publishes **core** BI views (`bi.*`)  
3. *(Optional)* **03c_bi_extra_views.sql** — publishes **extra** BI views  
4. **03b_bi_readme_queries.sql** — queries for screenshots **06–10**  
5. **03d_bi_extra_readme_queries.sql** — queries for screenshots **11–13**

## Published BI views

### Core (from `03a_publish_bi_views.sql`)
- `bi.v_orders_core` — one row per **valid** order + repaired timestamps + delivery KPIs  
  *(purchase_ts, approved_fixed, carrier_fixed, customer_fixed, estimated_delivery_date, actual_delivery_date, is_delivered, lead_time_days, late_flag)*
- `bi.v_order_items_enriched` — valid items + product category  
  *(order_id, order_item_id, product_id, product_category, price, freight_value)*
- `bi.v_payments_per_order` — valid payments aggregated per order  
  *(order_id, order_payment_total)*
- `bi.v_daily_sales` — delivered orders & sales by purchase date  
  *(purchase_date, delivered_orders, revenue_without_freight, freight_total, gross_sales)*
- `bi.v_delivery_lead_time` — lead time (days) for delivered orders  
  *(order_id, purchase_date, lead_time_days)*
- `bi.v_late_orders` — delivered orders that exceeded the estimate  
  *(order_id, purchase_ts, actual_delivery_date, estimated_delivery_date, lead_time_days, late_flag)*
- `bi.v_payment_mix` — share of payment types (by transactions and amount)  
  *(payment_type, txn_count, amount, pct_txn, pct_amount)*
- `bi.v_kpi_summary` — single-row KPI snapshot  
  *(total_orders_raw, invalid_orders, valid_orders, invalid_ratio, delivered_orders_valid, avg_lead_time_days, late_orders)*

### Extra (from `03c_bi_extra_views.sql`)
- `bi.v_category_sales_monthly` — delivered sales by **category × month**  
  *(month_start, product_category, delivered_orders, revenue_wo_freight, freight_total, gross_sales)*
- `bi.v_state_lead_time` — lead time by **state** (avg, p50, p90)  
  *(customer_state, delivered_orders, avg_lead_time_days, p50_lead_time, p90_lead_time)*
- `bi.v_repeat_customers` — repeater flag + gross sales per customer  
  *(customer_id, orders_cnt, is_repeater, gross_sales)*

## Evidence (screenshots)

All outputs are already captured in **`./screenshot/`** for reproducibility:

- **06 — KPI snapshot:**  
  [`readme_06_bi_kpi_summary.png`](./screenshot/readme_06_bi_kpi_summary.png)
- **07 — Daily sales:**  
  [`readme_07_bi_daily_sales.png`](./screenshot/readme_07_bi_daily_sales.png)
- **08 — Payment mix:**  
  [`readme_08_bi_payment_mix.png`](./screenshot/readme_08_bi_payment_mix.png)
- **09 — Late orders (top by lead time):**  
  [`readme_09_bi_late_orders.png`](./screenshot/readme_09_bi_late_orders.png)
- **10 — Lead-time distribution:**  
  [`readme_10_bi_lead_time_dist.png`](./screenshot/readme_10_bi_lead_time_dist.png)
- **11 — Category × month:**  
  [`readme_11_bi_category_monthly.png`](./screenshot/readme_11_bi_category_monthly.png)
- **12 — Lead time by state (avg / p50 / p90):**  
  [`readme_12_bi_state_lead_time.png`](./screenshot/readme_12_bi_state_lead_time.png)
- **13 — Repeat customers:**  
  [`readme_13_bi_repeat_customers.png`](./screenshot/readme_13_bi_repeat_customers.png)

## Quick notes
- **Reproducible & idempotent** — safe to re-run (`CREATE OR ALTER VIEW`)  
- Naming style: `lower_snake_case`  
- **Upstream dependency:** requires `quality.*` views from the **99 layer**  
- **Recommended inputs for dashboards:**  
  `bi.v_kpi_summary`, `bi.v_daily_sales`, `bi.v_payment_mix`,  
  `bi.v_state_lead_time`, `bi.v_category_sales_monthly`, `bi.v_repeat_customers`

## Environment notes
- After creating views, SSMS may temporarily highlight names in red due to IntelliSense cache. Refresh with **Ctrl+Shift+R**.  
- Required privileges: **CREATE VIEW** on schemas `quality` and `bi`.  
- State percentiles use **PERCENTILE_CONT** (SQL Server **2019+**).

---

*Dataset: Olist e-commerce (public). SQL provided for portfolio/demo purposes; dataset ownership remains with the original authors.*

