/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 03a_publish_bi_views.sql
  Purpose  : Publish BI-ready views built only from quality-safe data.
  Context  : Assumes 99c_quality_fixes.sql has been executed.
  Author   : Daiana Beltran
  Notes    : Read-only (CREATE OR ALTER VIEW). Safe to re-run.
==============================================================================*/

USE olist_sqlsrv;
GO

/* 0) Ensure BI schema exists */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bi')
    EXEC('CREATE SCHEMA bi');
GO

/*------------------------------------------------------------------------------
  1) Core orders (grain: 1 row per order)
     Inputs : quality.valid_orders (vo), quality.orders_repaired (qr)
     Fields : purchase_ts, repaired timestamps, lead_time_days, late_flag
     Rule   : “Late” = actual_delivery_date > estimated (end-of-day inclusive)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_orders_core
AS
SELECT
    vo.order_id,
    vo.customer_id,
    vo.order_status,
    vo.order_purchase_timestamp                  AS purchase_ts,
    qr.approved_fixed,
    qr.carrier_fixed,
    qr.customer_fixed,
    vo.order_estimated_delivery_date             AS estimated_delivery_date,
    COALESCE(qr.customer_fixed, vo.order_delivered_customer_date) AS actual_delivery_date,
    CASE WHEN vo.order_status = 'delivered' THEN 1 ELSE 0 END     AS is_delivered,
    CASE
        WHEN COALESCE(qr.customer_fixed, vo.order_delivered_customer_date) IS NOT NULL
        THEN DATEDIFF(DAY, vo.order_purchase_timestamp,
                           COALESCE(qr.customer_fixed, vo.order_delivered_customer_date))
    END AS lead_time_days,
    CASE
        WHEN COALESCE(qr.customer_fixed, vo.order_delivered_customer_date) IS NOT NULL
         AND vo.order_estimated_delivery_date IS NOT NULL
         AND COALESCE(qr.customer_fixed, vo.order_delivered_customer_date)
                 > DATEADD(DAY, 1, CONVERT(datetime2(0), vo.order_estimated_delivery_date))
        THEN 1 ELSE 0
    END AS late_flag
FROM quality.valid_orders AS vo
LEFT JOIN quality.orders_repaired AS qr
  ON qr.order_id = vo.order_id;
GO

/*------------------------------------------------------------------------------
  2) Enriched order items (grain: order_id + order_item_id)
     Inputs : quality.order_items_valid, clean.products
     Adds   : product_category (default 'unknown')
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_order_items_enriched
AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    COALESCE(p.product_category_name, N'unknown') AS product_category,
    oi.price,
    oi.freight_value
FROM quality.order_items_valid AS oi
LEFT JOIN clean.products AS p
  ON p.product_id = oi.product_id;
GO

/*------------------------------------------------------------------------------
  3) Payments per order (grain: 1 row per order)
     Inputs : quality.payments_valid
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_payments_per_order
AS
SELECT
    pv.order_id,
    SUM(pv.payment_value) AS order_payment_total
FROM quality.payments_valid AS pv
GROUP BY pv.order_id;
GO

/*------------------------------------------------------------------------------
  4) Daily sales (grain: purchase_date)
     Inputs : bi.v_orders_core, bi.v_order_items_enriched
     Filter : delivered only
     Note   : Aggregates by purchase date (not delivery date)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_daily_sales
AS
SELECT
    CAST(oc.purchase_ts AS date)                   AS purchase_date,
    COUNT(DISTINCT oc.order_id)                    AS delivered_orders,
    SUM(oi.price)                                  AS revenue_without_freight,
    SUM(oi.freight_value)                          AS freight_total,
    SUM(oi.price + oi.freight_value)               AS gross_sales
FROM bi.v_orders_core AS oc
JOIN bi.v_order_items_enriched AS oi
  ON oi.order_id = oc.order_id
WHERE oc.is_delivered = 1
GROUP BY CAST(oc.purchase_ts AS date);
GO

/*------------------------------------------------------------------------------
  5) Delivery lead time (grain: order_id)
     Inputs : bi.v_orders_core
     Filter : delivered only and non-null lead time
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_delivery_lead_time
AS
SELECT
    oc.order_id,
    CAST(oc.purchase_ts AS date) AS purchase_date,
    oc.lead_time_days
FROM bi.v_orders_core AS oc
WHERE oc.is_delivered = 1
  AND oc.lead_time_days IS NOT NULL;
GO

/*------------------------------------------------------------------------------
  6) Late orders (grain: order_id)
     Inputs : bi.v_orders_core
     Filter : delivered AND late_flag = 1
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_late_orders
AS
SELECT
    oc.order_id,
    oc.purchase_ts,
    oc.actual_delivery_date,
    oc.estimated_delivery_date,
    oc.lead_time_days,
    oc.late_flag
FROM bi.v_orders_core AS oc
WHERE oc.is_delivered = 1
  AND oc.late_flag = 1;
GO

/*------------------------------------------------------------------------------
  7) Payment mix (grain: payment_type)
     Inputs : quality.payments_valid
     Notes  : Adds % by transactions and by amount
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_payment_mix
AS
SELECT
    COALESCE(pv.payment_type, N'unknown')          AS payment_type,
    COUNT(*)                                       AS txn_count,
    SUM(pv.payment_value)                          AS amount,
    CAST(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(6,2))        AS pct_txn,
    CAST(100.0 * SUM(pv.payment_value) / NULLIF(SUM(SUM(pv.payment_value)) OVER (), 0)
         AS DECIMAL(6,2))                                                                AS pct_amount
FROM quality.payments_valid AS pv
GROUP BY COALESCE(pv.payment_type, N'unknown');
GO

/*------------------------------------------------------------------------------
  8) KPI summary (single-row snapshot for README cards)
     Includes: totals (raw/clean), invalid ratio, delivered & on-time KPIs
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_kpi_summary
AS
SELECT
  (SELECT COUNT(*) FROM raw.orders)                               AS total_orders_raw,
  (SELECT COUNT(*) FROM clean.orders)                             AS total_orders_clean,
  (SELECT COUNT(*) FROM quality.invalid_orders_ids)               AS invalid_orders,
  CAST(
    CASE WHEN (SELECT COUNT(*) FROM raw.orders) = 0
         THEN 0.0
         ELSE 1.0 * (SELECT COUNT(*) FROM quality.invalid_orders_ids)
                    / NULLIF((SELECT COUNT(*) FROM raw.orders), 0)
    END AS DECIMAL(6,4)
  ) AS invalid_ratio_vs_raw,
  (SELECT COUNT(*) FROM bi.v_orders_core WHERE is_delivered = 1)  AS delivered_orders_valid,
  (SELECT COUNT(*) FROM bi.v_orders_core WHERE is_delivered = 1 AND late_flag = 0) AS on_time_orders,
  (SELECT CAST(AVG(CAST(lead_time_days AS DECIMAL(10,2))) AS DECIMAL(10,2))
     FROM bi.v_orders_core WHERE is_delivered = 1)                AS avg_lead_time_days,
  (SELECT CAST(100.0 *
               SUM(CASE WHEN late_flag = 1 THEN 1 ELSE 0 END)
               / NULLIF(COUNT(*),0) AS DECIMAL(6,2))
     FROM bi.v_orders_core WHERE is_delivered = 1)                AS late_rate_pct
;
GO

/*-- Example selects (keep commented)
-- SELECT TOP (10) * FROM bi.v_daily_sales ORDER BY purchase_date;
-- SELECT TOP (10) * FROM bi.v_delivery_lead_time ORDER BY lead_time_days DESC;
-- SELECT * FROM bi.v_payment_mix ORDER BY pct_amount DESC;
-- SELECT * FROM bi.v_kpi_summary;
*/

