/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 03a_publish_bi_views.sql
  Purpose  : Publish BI-ready views built only from quality-safe data.
  Context  : Assumes 99c_quality_fixes.sql has been executed.
  Author   : Daiana Beltran
  Date     : 2025-09-05
  Notes    : Read-only (CREATE OR ALTER VIEW). Safe to re-run.
==============================================================================*/

USE olist_sqlsrv;
GO

/*------------------------------------------------------------------------------
  0) Ensure BI schema exists
------------------------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bi')
    EXEC('CREATE SCHEMA bi');
GO

/*------------------------------------------------------------------------------
  1) Core orders view (valid + repaired timestamps)
     - Uses quality.valid_orders and quality.orders_repaired
     - Adds BI-friendly fields: actual_delivery_date, lead_time_days, late_flag
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_orders_core
AS
SELECT
    vo.order_id,
    vo.customer_id,
    vo.order_status,
    vo.order_purchase_timestamp          AS purchase_ts,
    qr.approved_fixed,
    qr.carrier_fixed,
    qr.customer_fixed,
    vo.order_estimated_delivery_date     AS estimated_delivery_date,
    -- prefer the repaired customer date when available
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
         AND COALESCE(qr.customer_fixed, vo.order_delivered_customer_date) > vo.order_estimated_delivery_date
        THEN 1 ELSE 0
    END AS late_flag
FROM quality.valid_orders AS vo
JOIN quality.orders_repaired AS qr
  ON qr.order_id = vo.order_id;
GO

/*------------------------------------------------------------------------------
  2) Enriched order items (valid items + product category)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_order_items_enriched
AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    COALESCE(p.product_category_name, 'unknown') AS product_category,
    oi.price,
    oi.freight_value
FROM quality.order_items_valid AS oi
LEFT JOIN clean.products AS p
  ON p.product_id = oi.product_id;
GO

/*------------------------------------------------------------------------------
  3) Payments summary per order (valid payments)
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
  4) Daily sales (delivered orders only) using valid items
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
  5) Delivery lead time distribution (delivered only)
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
  6) Late orders overview (delivered only)
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
  7) Payment mix (share of payment types over valid payments)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_payment_mix
AS
SELECT
    pv.payment_type,
    COUNT(*)                         AS txn_count,
    SUM(pv.payment_value)            AS amount,
    CAST(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(6,2)) AS pct_txn,
    CAST(100.0 * SUM(pv.payment_value) / NULLIF(SUM(SUM(pv.payment_value)) OVER (), 0) AS DECIMAL(6,2)) AS pct_amount
FROM quality.payments_valid AS pv
GROUP BY pv.payment_type;
GO

/*------------------------------------------------------------------------------
  8) KPI summary for README (quick snapshot)
------------------------------------------------------------------------------*/
CREATE OR ALTER VIEW bi.v_kpi_summary
AS
SELECT
  (SELECT COUNT(*) FROM clean.orders)                             AS total_orders_raw,
  (SELECT COUNT(*) FROM quality.invalid_orders_ids)               AS invalid_orders,
  (SELECT COUNT(*) FROM quality.valid_orders)                     AS valid_orders,
  CAST(
    CASE WHEN (SELECT COUNT(*) FROM clean.orders) = 0
         THEN 0.0
         ELSE 1.0 * (SELECT COUNT(*) FROM quality.invalid_orders_ids)
                    / NULLIF((SELECT COUNT(*) FROM clean.orders), 0)
    END AS DECIMAL(6,4)
  ) AS invalid_ratio,
  (SELECT COUNT(*) FROM bi.v_orders_core WHERE is_delivered = 1)  AS delivered_orders_valid,
  (SELECT AVG(CAST(lead_time_days AS DECIMAL(10,2))) FROM bi.v_orders_core WHERE is_delivered = 1) AS avg_lead_time_days,
  (SELECT COUNT(*) FROM bi.v_late_orders)                         AS late_orders
;
GO

/*------------------------------------------------------------------------------
  9) (Optional) Example selects — keep commented
------------------------------------------------------------------------------*/
-- SELECT TOP (10) * FROM bi.v_daily_sales ORDER BY purchase_date;
-- SELECT TOP (10) * FROM bi.v_delivery_lead_time ORDER BY lead_time_days DESC;
-- SELECT * FROM bi.v_payment_mix ORDER BY pct_amount DESC;
-- SELECT * FROM bi.v_kpi_summary;
