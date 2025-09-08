/* ===========================================================
   Project : Olist — SQL Server
   Script  : 99b_quality_deep_checks.sql
   Author  : Daiana Beltrán
   Purpose : Deep data quality checks over CLEAN
   RunOrder: 99b
   Idempotent: Yes
   =========================================================== */
USE olist_sqlsrv;
SET NOCOUNT ON;

------------------------------------------------------------
-- 1) Uniqueness (candidatos a PK)
------------------------------------------------------------
SELECT 'dup_orders' AS check_name, COUNT(*) AS cnt
FROM (SELECT order_id FROM clean.orders GROUP BY order_id HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'dup_customers', COUNT(*) FROM (SELECT customer_id FROM clean.customers GROUP BY customer_id HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'dup_products', COUNT(*)  FROM (SELECT product_id  FROM clean.products  GROUP BY product_id  HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'dup_reviews', COUNT(*)   FROM (SELECT review_id   FROM clean.reviews   GROUP BY review_id   HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'dup_sellers', COUNT(*)   FROM (SELECT seller_id   FROM clean.sellers   GROUP BY seller_id   HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'dup_order_items_key', COUNT(*)   -- (order_id, order_item_id) debe ser único
FROM (
  SELECT order_id, order_item_id
  FROM clean.order_items
  GROUP BY order_id, order_item_id
  HAVING COUNT(*) > 1
) d
UNION ALL
SELECT 'dup_payments_key', COUNT(*)      -- (order_id, payment_sequential) debe ser único
FROM (
  SELECT order_id, payment_sequential
  FROM clean.payments
  GROUP BY order_id, payment_sequential
  HAVING COUNT(*) > 1
) d;

------------------------------------------------------------
-- 2) Nulls en claves y campos críticos
------------------------------------------------------------
SELECT 'nulls_orders_pk' AS check_name, COUNT(*) AS cnt
FROM clean.orders WHERE order_id IS NULL
UNION ALL
SELECT 'nulls_items_key', COUNT(*)
FROM clean.order_items
WHERE order_id IS NULL OR order_item_id IS NULL
UNION ALL
SELECT 'nulls_payments_key', COUNT(*)
FROM clean.payments
WHERE order_id IS NULL OR payment_sequential IS NULL
UNION ALL
SELECT 'nulls_reviews_key', COUNT(*)
FROM clean.reviews
WHERE review_id IS NULL OR order_id IS NULL;

------------------------------------------------------------
-- 3) Dominios y rangos
------------------------------------------------------------
-- order_status permitido
SELECT 'bad_order_status', COUNT(*)
FROM clean.orders
WHERE order_status NOT IN ('created','approved','invoiced','shipped','delivered','canceled','unavailable','processing')
UNION ALL
-- review score 1..5
SELECT 'bad_review_score', COUNT(*) FROM clean.reviews WHERE review_score NOT BETWEEN 1 AND 5
UNION ALL
-- payments: valores no negativos e installments >= 0
SELECT 'neg_payment_value', COUNT(*) FROM clean.payments WHERE payment_value < 0
UNION ALL
SELECT 'neg_installments', COUNT(*) FROM clean.payments WHERE payment_installments < 0
UNION ALL
-- items: precios/flete no negativos
SELECT 'neg_item_money', COUNT(*) FROM clean.order_items WHERE price < 0 OR freight_value < 0
UNION ALL
-- UF de 2 letras (clientes y sellers)
SELECT 'bad_customer_state_len', COUNT(*) FROM clean.customers WHERE LEN(LTRIM(RTRIM(customer_state))) <> 2
UNION ALL
SELECT 'bad_seller_state_len', COUNT(*)   FROM clean.sellers   WHERE LEN(LTRIM(RTRIM(seller_state))) <> 2;

------------------------------------------------------------
-- 4) Lógica temporal
------------------------------------------------------------
SELECT 'bad_time_logic' AS check_name, COUNT(*) AS cnt
FROM clean.orders
WHERE (order_approved_at             IS NOT NULL AND order_approved_at             < order_purchase_timestamp)
   OR (order_delivered_carrier_date  IS NOT NULL AND order_delivered_carrier_date  < order_purchase_timestamp)
   OR (order_delivered_customer_date IS NOT NULL AND order_delivered_customer_date < order_purchase_timestamp)
   OR (order_estimated_delivery_date IS NOT NULL AND order_estimated_delivery_date < CAST(order_purchase_timestamp AS date));

------------------------------------------------------------
-- 5) Consistencia económico-contable
------------------------------------------------------------
WITH items AS (
  SELECT order_id, SUM(price + freight_value) AS items_total
  FROM clean.order_items GROUP BY order_id
),
pays AS (
  SELECT order_id, SUM(payment_value) AS pay_total
  FROM clean.payments GROUP BY order_id
)
SELECT TOP (20)
  i.order_id, i.items_total, p.pay_total,
  (p.pay_total - i.items_total) AS diff
FROM items i
JOIN pays  p ON p.order_id = i.order_id
WHERE ABS(p.pay_total - i.items_total) > 0.01   -- tolerancia
ORDER BY ABS(p.pay_total - i.items_total) DESC;

------------------------------------------------------------
-- 6) Forzar que los FKs queden TRUSTED (si se crearon con WITH NOCHECK)
------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_items_order')
  ALTER TABLE clean.order_items WITH CHECK CHECK CONSTRAINT FK_items_order;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_items_product')
  ALTER TABLE clean.order_items WITH CHECK CHECK CONSTRAINT FK_items_product;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_items_seller')
  ALTER TABLE clean.order_items WITH CHECK CHECK CONSTRAINT FK_items_seller;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_payments_order')
  ALTER TABLE clean.payments   WITH CHECK CHECK CONSTRAINT FK_payments_order;

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_reviews_order')
  ALTER TABLE clean.reviews    WITH CHECK CHECK CONSTRAINT FK_reviews_order;

-- Estado de FKs
SELECT name, is_disabled, is_not_trusted
FROM sys.foreign_keys
WHERE parent_object_id IN (
  OBJECT_ID('clean.order_items'),
  OBJECT_ID('clean.payments'),
  OBJECT_ID('clean.reviews')
);
