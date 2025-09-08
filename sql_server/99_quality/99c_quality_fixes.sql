/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 99c_quality_fixes.sql
  Purpose  : Publish final “quality-safe” views and summaries after deep checks.
  Context  : Olist dataset on SQL Server (schema: clean.*)
  Author   : Daiana Beltrán
  Notes    :
    - This script does NOT mutate source tables. It exposes views:
        * quality.invalid_orders_time_logic      -> one row per violation
        * quality.invalid_orders_ids             -> distinct bad order_ids
        * quality.invalid_orders_summary         -> count by violation
        * quality.valid_orders                   -> orders minus violations
        * quality.order_items_valid              -> items only from valid orders
        * quality.payments_valid                 -> payments only from valid orders
        * quality.orders_repaired (optional)     -> non-destructive “fixed” timestamps
    - Designed to be re-runnable (CREATE OR ALTER).
==============================================================================*/

USE olist_sqlsrv;
GO

/* 0) Namespace for quality artifacts */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'quality')
    EXEC('CREATE SCHEMA quality');
GO

/* 1) Temporal logic violations (multi-hit per order) */
CREATE OR ALTER VIEW quality.invalid_orders_time_logic
AS
WITH base AS (
    SELECT
        o.order_id,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM clean.orders AS o
)
SELECT
    b.order_id,
    b.order_purchase_timestamp,
    b.order_approved_at,
    b.order_delivered_carrier_date,
    b.order_delivered_customer_date,
    b.order_estimated_delivery_date,
    v.violation_code,
    v.violation_description
FROM base AS b
CROSS APPLY (
    VALUES
      ('T1', CASE
             WHEN b.order_approved_at IS NOT NULL
              AND b.order_purchase_timestamp IS NOT NULL
              AND b.order_approved_at < b.order_purchase_timestamp
             THEN 'approved_at earlier than purchase_timestamp' END),
      ('T2', CASE
             WHEN b.order_delivered_carrier_date IS NOT NULL
              AND b.order_approved_at IS NOT NULL
              AND b.order_delivered_carrier_date < b.order_approved_at
             THEN 'carrier_date earlier than approved_at' END),
      ('T3', CASE
             WHEN b.order_delivered_customer_date IS NOT NULL
              AND b.order_delivered_carrier_date IS NOT NULL
              AND b.order_delivered_customer_date < b.order_delivered_carrier_date
             THEN 'customer_date earlier than carrier_date' END),
      ('T4', CASE
             WHEN b.order_delivered_customer_date IS NOT NULL
              AND b.order_purchase_timestamp IS NOT NULL
              AND b.order_delivered_customer_date < b.order_purchase_timestamp
             THEN 'customer_date earlier than purchase_timestamp' END)
) AS v(violation_code, violation_description)
WHERE v.violation_description IS NOT NULL;
GO

/* 2) Distinct invalid order_ids */
CREATE OR ALTER VIEW quality.invalid_orders_ids
AS
SELECT DISTINCT order_id
FROM quality.invalid_orders_time_logic;
GO

/* 3) Summary of violations */
CREATE OR ALTER VIEW quality.invalid_orders_summary
AS
SELECT
    violation_code,
    violation_description,
    COUNT(*) AS violation_count
FROM quality.invalid_orders_time_logic
GROUP BY violation_code, violation_description;
GO

/* 4) Valid orders = clean.orders minus violations */
CREATE OR ALTER VIEW quality.valid_orders
AS
SELECT o.*
FROM clean.orders AS o
WHERE NOT EXISTS (
    SELECT 1
    FROM quality.invalid_orders_ids AS bad
    WHERE bad.order_id = o.order_id
);
GO

/* 5) Valid order_items and payments scoped to valid orders */
CREATE OR ALTER VIEW quality.order_items_valid
AS
SELECT oi.*
FROM clean.order_items AS oi
INNER JOIN quality.valid_orders AS vo
    ON vo.order_id = oi.order_id;
GO

CREATE OR ALTER VIEW quality.payments_valid
AS
SELECT p.*
FROM clean.payments AS p
INNER JOIN quality.valid_orders AS vo
    ON vo.order_id = p.order_id;
GO

/* 6) “Repaired” orders (non-destructive monotonic fix) */
CREATE OR ALTER VIEW quality.orders_repaired
AS
SELECT
    o.order_id,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    a.approved_fixed,
    c.carrier_fixed,
    d.customer_fixed
FROM clean.orders AS o
CROSS APPLY (
    SELECT approved_fixed =
        CASE
            WHEN o.order_approved_at IS NOT NULL
             AND o.order_purchase_timestamp IS NOT NULL
             AND o.order_approved_at < o.order_purchase_timestamp
            THEN o.order_purchase_timestamp
            ELSE o.order_approved_at
        END
) AS a
CROSS APPLY (
    SELECT carrier_fixed =
        CASE
            WHEN o.order_delivered_carrier_date IS NOT NULL
             AND (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed)) AS t(v)) IS NOT NULL
             AND o.order_delivered_carrier_date <
                 (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed)) AS t(v))
            THEN (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed)) AS t(v))
            ELSE o.order_delivered_carrier_date
        END
) AS c
CROSS APPLY (
    SELECT customer_fixed =
        CASE
            WHEN o.order_delivered_customer_date IS NOT NULL
             AND (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed),(c.carrier_fixed)) AS t(v)) IS NOT NULL
             AND o.order_delivered_customer_date <
                 (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed),(c.carrier_fixed)) AS t(v))
            THEN (SELECT MAX(v) FROM (VALUES (o.order_purchase_timestamp),(a.approved_fixed),(c.carrier_fixed)) AS t(v))
            ELSE o.order_delivered_customer_date
        END
) AS d;
GO

/* 7) KPI snapshot (single row) */
CREATE OR ALTER VIEW quality.orders_quality_snapshot
AS
SELECT
    (SELECT COUNT(*) FROM clean.orders)   AS total_orders,
    (SELECT COUNT(*) FROM quality.invalid_orders_ids) AS invalid_orders,
    (SELECT COUNT(*) FROM quality.valid_orders)       AS valid_orders,
    CAST(
        CASE WHEN (SELECT COUNT(*) FROM clean.orders) = 0
             THEN 0.0
             ELSE 1.0 * (SELECT COUNT(*) FROM quality.invalid_orders_ids)
                        / NULLIF((SELECT COUNT(*) FROM clean.orders), 0)
        END AS DECIMAL(6,4)
    ) AS invalid_ratio;
GO

-- (Examples left commented)
-- SELECT TOP (20) * FROM quality.invalid_orders_time_logic ORDER BY order_purchase_timestamp;
-- SELECT * FROM quality.invalid_orders_summary ORDER BY violation_count DESC;
-- SELECT TOP (20) * FROM quality.valid_orders ORDER BY order_purchase_timestamp;
-- SELECT TOP (20) * FROM quality.orders_repaired ORDER BY order_purchase_timestamp;
-- SELECT * FROM quality.orders_quality_snapshot;
