/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 03c_bi_extra_views.sql
  Purpose  : Extra BI views (category/month sales, state lead time, repeaters).
  Context  : Assumes 99c_quality_fixes.sql and 03a_publish_bi_views.sql were run.
  Author   : Daiana Beltran
  Notes    : Read-only (CREATE OR ALTER VIEW). Safe to re-run.
==============================================================================*/

USE olist_sqlsrv;
SET NOCOUNT ON;
GO

/* Safety: ensure BI schema exists */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bi')
    EXEC('CREATE SCHEMA bi');
GO

/*------------------------------------------------------------------------------
  1) Monthly sales by product category (grain: month_start × category)
     Inputs : bi.v_orders_core, bi.v_order_items_enriched
     Filter : delivered only
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_category_sales_monthly
AS
SELECT
    DATEFROMPARTS(YEAR(oc.purchase_ts), MONTH(oc.purchase_ts), 1) AS month_start,
    oi.product_category,
    COUNT(DISTINCT oc.order_id)                                   AS delivered_orders,
    SUM(oi.price)                                                 AS revenue_wo_freight,
    SUM(oi.freight_value)                                         AS freight_total,
    SUM(oi.price + oi.freight_value)                              AS gross_sales
FROM bi.v_orders_core          AS oc
JOIN bi.v_order_items_enriched AS oi
  ON oi.order_id = oc.order_id
WHERE oc.is_delivered = 1
GROUP BY
    DATEFROMPARTS(YEAR(oc.purchase_ts), MONTH(oc.purchase_ts), 1),
    oi.product_category;
GO

/*------------------------------------------------------------------------------
  2) Lead time by customer state (grain: state)
     Inputs : bi.v_orders_core, clean.customers
     Metrics: avg, p50, p90 (percentiles computed via window + group)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_state_lead_time
AS
WITH base AS (
    SELECT
        c.customer_state,
        CAST(oc.lead_time_days AS DECIMAL(10,2)) AS lead_time_days
    FROM bi.v_orders_core AS oc
    JOIN clean.customers  AS c
      ON c.customer_id = oc.customer_id
    WHERE oc.is_delivered = 1
      AND oc.lead_time_days IS NOT NULL
),
p AS (
    SELECT
        customer_state,
        lead_time_days,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lead_time_days)
            OVER (PARTITION BY customer_state) AS p50_lead_time,
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY lead_time_days)
            OVER (PARTITION BY customer_state) AS p90_lead_time
    FROM base
)
SELECT
    customer_state,
    COUNT(*)            AS delivered_orders,
    AVG(lead_time_days) AS avg_lead_time_days,
    MAX(p50_lead_time)  AS p50_lead_time,
    MAX(p90_lead_time)  AS p90_lead_time
FROM p
GROUP BY customer_state;
GO

/*------------------------------------------------------------------------------
  3) Repeat customers (grain: customer_id)
     Inputs : bi.v_orders_core, bi.v_order_items_enriched
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_repeat_customers
AS
WITH orders_per_c AS (
    SELECT oc.customer_id, COUNT(*) AS orders_cnt
    FROM bi.v_orders_core AS oc
    WHERE oc.is_delivered = 1
    GROUP BY oc.customer_id
),
spend_per_c AS (
    SELECT
        oc.customer_id,
        SUM(oi.price + oi.freight_value) AS gross_sales
    FROM bi.v_orders_core          AS oc
    JOIN bi.v_order_items_enriched AS oi
      ON oi.order_id = oc.order_id
    WHERE oc.is_delivered = 1
    GROUP BY oc.customer_id
)
SELECT
    o.customer_id,
    o.orders_cnt,
    CASE WHEN o.orders_cnt > 1 THEN 1 ELSE 0 END AS is_repeater,
    s.gross_sales
FROM orders_per_c o
LEFT JOIN spend_per_c s
  ON s.customer_id = o.customer_id;
GO

/* -- Example selects (keep commented)
-- SELECT TOP (12) * FROM bi.v_category_sales_monthly ORDER BY month_start DESC, gross_sales DESC;
-- SELECT TOP (10) * FROM bi.v_state_lead_time ORDER BY avg_lead_time_days DESC;
-- SELECT TOP (15) * FROM bi.v_repeat_customers ORDER BY orders_cnt DESC;
*/

