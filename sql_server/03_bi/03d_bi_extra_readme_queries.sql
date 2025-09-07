/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 03d_bi_extra_readme_queries.sql
  Purpose  : Run BI extra queries (for README screenshots of 03c views).
  Context  : Assumes 03a_publish_bi_views.sql and 03c_bi_extra_views.sql were run.
  Author   : Daiana Beltran
  Date     : 2025-09-06
  Notes    : Read-only. Execute each block and take a screenshot of the grid.
==============================================================================*/

USE olist_sqlsrv;
SET NOCOUNT ON;
GO

/*------------------------------------------------------------------------------
  1) Category × Month sales (delivered only) — sample for screenshot
      Screenshot name: readme_11_bi_category_monthly.png
------------------------------------------------------------------------------*/
SELECT TOP (15)
    month_start,
    product_category,
    delivered_orders,
    revenue_wo_freight,
    freight_total,
    gross_sales
FROM bi.v_category_sales_monthly
ORDER BY month_start DESC, gross_sales DESC;   -- compact & business-friendly
GO

/*------------------------------------------------------------------------------
  2) Lead time by customer state — ranks by average lead time
      Screenshot name: readme_12_bi_state_lead_time.png
------------------------------------------------------------------------------*/
SELECT TOP (12)
    customer_state,
    delivered_orders,
    CAST(avg_lead_time_days AS DECIMAL(10,2)) AS avg_lead_time_days,
    CAST(p50_lead_time      AS DECIMAL(10,2)) AS p50_lead_time,
    CAST(p90_lead_time      AS DECIMAL(10,2)) AS p90_lead_time
FROM bi.v_state_lead_time
ORDER BY avg_lead_time_days DESC;
GO

/*------------------------------------------------------------------------------
  3) Repeat customers — who buys more than once (quick sample)
      Screenshot name: readme_13_bi_repeat_customers.png
------------------------------------------------------------------------------*/
SELECT TOP (15)
    customer_id,
    orders_cnt,
    is_repeater,
    CAST(gross_sales AS DECIMAL(12,2)) AS gross_sales
FROM bi.v_repeat_customers
ORDER BY orders_cnt DESC, gross_sales DESC;
GO
