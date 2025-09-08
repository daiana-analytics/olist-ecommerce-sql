/*
  Project   : Olist — SQL Server
  Script    : 99a_quality_checks.sql
  Author    : Daiana Beltrán
  Purpose   : Sanity checks (nulls, orphans, RAW vs CLEAN row counts)
  RunOrder  : 99a
  Idempotent: Yes
*/
USE olist_sqlsrv;
SET NOCOUNT ON;

------------------------------------------------------------
-- 1) Row counts RAW vs CLEAN (deben coincidir o ser esperados)
------------------------------------------------------------
SELECT 'orders'        AS lbl,
       (SELECT COUNT(*) FROM raw.orders)        AS raw_ct,
       (SELECT COUNT(*) FROM clean.orders)      AS clean_ct
UNION ALL SELECT 'order_items',
       (SELECT COUNT(*) FROM raw.order_items),
       (SELECT COUNT(*) FROM clean.order_items)
UNION ALL SELECT 'payments',
       (SELECT COUNT(*) FROM raw.payments),
       (SELECT COUNT(*) FROM clean.payments)
UNION ALL SELECT 'reviews',
       (SELECT COUNT(*) FROM raw.reviews),
       (SELECT COUNT(*) FROM clean.reviews)
UNION ALL SELECT 'customers',
       (SELECT COUNT(*) FROM raw.customers),
       (SELECT COUNT(*) FROM clean.customers)
UNION ALL SELECT 'sellers',
       (SELECT COUNT(*) FROM raw.sellers),
       (SELECT COUNT(*) FROM clean.sellers)
UNION ALL SELECT 'products',
       (SELECT COUNT(*) FROM raw.products),
       (SELECT COUNT(*) FROM clean.products);
GO

------------------------------------------------------------
-- 2) Orphans (deben ser 0)
--    NOT EXISTS evita falsos positivos por duplicados.
------------------------------------------------------------
SELECT 'items_without_order'   AS check_name, COUNT(*) AS cnt
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = oi.order_id);

SELECT 'items_without_product' AS check_name, COUNT(*) AS cnt
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.products p WHERE p.product_id = oi.product_id);

SELECT 'items_without_seller'  AS check_name, COUNT(*) AS cnt
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.sellers s WHERE s.seller_id = oi.seller_id);

SELECT 'payments_without_order' AS check_name, COUNT(*) AS cnt
FROM clean.payments p
WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = p.order_id);

SELECT 'reviews_without_order' AS check_name, COUNT(*) AS cnt
FROM clean.reviews r
WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = r.order_id);

-- Útil si los FKs aún no estaban validados:
SELECT 'orders_without_customer' AS check_name, COUNT(*) AS cnt
FROM clean.orders o
WHERE NOT EXISTS (SELECT 1 FROM clean.customers c WHERE c.customer_id = o.customer_id);
GO
