/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 99d_quality_sanity_checks.sql
  Purpose  : Run read-only validation queries for portfolio screenshots.
  Context  : Assumes 99c_quality_fixes.sql has been executed.
  Author   : Daiana Beltrán
  Notes    : Read-only and safe to re-run.
==============================================================================*/

USE olist_sqlsrv;
GO

-- 1) Invalid orders (≈ 1.3k en el dataset original; tu número puede variar)
SELECT COUNT(*) AS invalid_orders
FROM quality.invalid_orders_ids;

-- 2) Reconciliación: valid + invalid = total
SELECT 
  (SELECT COUNT(*) FROM clean.orders)                           AS total_orders,
  (SELECT COUNT(*) FROM quality.invalid_orders_ids)             AS invalid_orders,
  (SELECT COUNT(*) FROM quality.valid_orders)                   AS valid_orders,
  (SELECT COUNT(*) FROM clean.orders) 
    - (SELECT COUNT(*) FROM quality.valid_orders)
    - (SELECT COUNT(*) FROM quality.invalid_orders_ids)         AS diff_should_be_zero;

-- 3) La vista “reparada” no debe violar la lógica temporal
SELECT COUNT(*) AS still_bad_after_fix
FROM quality.orders_repaired r
WHERE (r.approved_fixed IS NOT NULL AND r.order_purchase_timestamp IS NOT NULL 
       AND r.approved_fixed < r.order_purchase_timestamp)
   OR (r.carrier_fixed  IS NOT NULL AND r.approved_fixed IS NOT NULL 
       AND r.carrier_fixed  < r.approved_fixed)
   OR (r.customer_fixed IS NOT NULL AND r.carrier_fixed  IS NOT NULL 
       AND r.customer_fixed < r.carrier_fixed)
   OR (r.customer_fixed IS NOT NULL AND r.order_purchase_timestamp IS NOT NULL
       AND r.customer_fixed < r.order_purchase_timestamp);

-- 4) Breakdown por tipo de violación
SELECT * 
FROM quality.invalid_orders_summary 
ORDER BY violation_count DESC;

-- 5) Snapshot de ratio de calidad (single row para README)
SELECT *
FROM quality.orders_quality_snapshot;

-- 6) Listado de vistas publicadas (quality + bi si existe)
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bi')
BEGIN
    SELECT SCHEMA_NAME(v.schema_id) AS schema_name,
           v.name                   AS view_name
    FROM sys.views v
    WHERE SCHEMA_NAME(v.schema_id) IN ('quality','bi')
    ORDER BY schema_name, view_name;
END
ELSE
BEGIN
    SELECT SCHEMA_NAME(v.schema_id) AS schema_name,
           v.name                   AS view_name
    FROM sys.views v
    WHERE SCHEMA_NAME(v.schema_id) = 'quality'
    ORDER BY schema_name, view_name;
END

