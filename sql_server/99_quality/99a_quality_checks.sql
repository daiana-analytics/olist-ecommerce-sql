/*
  Project   : Olist — SQL Server
  Script    : 99a_quality_checks.sql
  Author    : Daiana Beltran
  Purpose   : Sanity checks (nulls, orphans, compare RAW vs CLEAN)
  RunOrder  : 99a
  Idempotent: Yes
*/
USE olist_sqlsrv;
SET NOCOUNT ON;

-- row counts RAW vs CLEAN (should match or be expected)
SELECT 'orders'        lbl, (SELECT COUNT(*) FROM raw.orders)   raw_ct, (SELECT COUNT(*) FROM clean.orders)   clean_ct
UNION ALL SELECT 'order_items', (SELECT COUNT(*) FROM raw.order_items), (SELECT COUNT(*) FROM clean.order_items)
UNION ALL SELECT 'payments',    (SELECT COUNT(*) FROM raw.payments),    (SELECT COUNT(*) FROM clean.payments)
UNION ALL SELECT 'reviews',     (SELECT COUNT(*) FROM raw.reviews),     (SELECT COUNT(*) FROM clean.reviews)
UNION ALL SELECT 'customers',   (SELECT COUNT(*) FROM raw.customers),   (SELECT COUNT(*) FROM clean.customers)
UNION ALL SELECT 'sellers',     (SELECT COUNT(*) FROM raw.sellers),     (SELECT COUNT(*) FROM clean.sellers)
UNION ALL SELECT 'products',    (SELECT COUNT(*) FROM raw.products),    (SELECT COUNT(*) FROM clean.products);

-- orphans (should be 0)
SELECT 'items_without_order' AS check_name, COUNT(*) AS cnt
FROM clean.order_items oi
LEFT JOIN clean.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

SELECT 'items_without_product' AS check_name, COUNT(*) AS cnt
FROM clean.order_items oi
LEFT JOIN clean.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;

SELECT 'payments_without_order' AS check_name, COUNT(*) AS cnt
FROM clean.payments p
LEFT JOIN clean.orders o ON o.order_id = p.order_id
WHERE o.order_id IS NULL;
GO
