/*
  Project   : Olist — SQL Server
  Script    : 02a_build_clean_tables.sql
  Author    : Daiana Beltran
  Purpose   : Build CLEAN tables from RAW with proper types, PK/FK and indexes
  RunOrder  : 02a
  Idempotent: Yes
*/
USE olist_sqlsrv;
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')
    EXEC('CREATE SCHEMA clean');

------------------------------------------------------------
-- 1) GEOLOCATION (canonical lat/lng per (zip,city,state))
------------------------------------------------------------
IF OBJECT_ID('clean.geolocation','U') IS NOT NULL DROP TABLE clean.geolocation;
CREATE TABLE clean.geolocation (
  geolocation_zip_code_prefix int NOT NULL,
  geolocation_city            nvarchar(100) NOT NULL,
  geolocation_state           nchar(2)      NOT NULL,
  geolocation_lat             float         NULL,
  geolocation_lng             float         NULL,
  CONSTRAINT PK_clean_geolocation PRIMARY KEY
    (geolocation_zip_code_prefix, geolocation_city, geolocation_state)
);

INSERT INTO clean.geolocation
SELECT
  t.geolocation_zip_code_prefix,
  t.geolocation_city,
  t.geolocation_state,
  AVG(t.geolocation_lat)  AS geolocation_lat,
  AVG(t.geolocation_lng)  AS geolocation_lng
FROM raw.geolocation t
GROUP BY
  t.geolocation_zip_code_prefix,
  t.geolocation_city,
  t.geolocation_state;

------------------------------------------------------------
-- 2) CUSTOMERS
------------------------------------------------------------
IF OBJECT_ID('clean.customers','U') IS NOT NULL DROP TABLE clean.customers;
CREATE TABLE clean.customers (
  customer_id              nvarchar(50) NOT NULL,
  customer_unique_id       nvarchar(50) NULL,
  customer_zip_code_prefix int          NULL,
  customer_city            nvarchar(100) NULL,
  customer_state           nchar(2)      NULL,
  CONSTRAINT PK_clean_customers PRIMARY KEY (customer_id)
);

INSERT INTO clean.customers
SELECT customer_id, customer_unique_id, customer_zip_code_prefix,
       customer_city, customer_state
FROM raw.customers;

CREATE INDEX IX_clean_customers_zip ON clean.customers(customer_zip_code_prefix);

------------------------------------------------------------
-- 3) SELLERS
------------------------------------------------------------
IF OBJECT_ID('clean.sellers','U') IS NOT NULL DROP TABLE clean.sellers;
CREATE TABLE clean.sellers (
  seller_id              nvarchar(50) NOT NULL,
  seller_zip_code_prefix int          NULL,
  seller_city            nvarchar(100) NULL,
  seller_state           nchar(2)      NULL,
  CONSTRAINT PK_clean_sellers PRIMARY KEY (seller_id)
);

INSERT INTO clean.sellers
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM raw.sellers;

CREATE INDEX IX_clean_sellers_zip ON clean.sellers(seller_zip_code_prefix);

------------------------------------------------------------
-- 4) PRODUCTS (with translated category)
------------------------------------------------------------
IF OBJECT_ID('clean.products','U') IS NOT NULL DROP TABLE clean.products;
CREATE TABLE clean.products (
  product_id                   nvarchar(50) NOT NULL,
  product_category_name        nvarchar(50) NULL,
  product_category_name_english nvarchar(50) NULL,
  product_name_lenght          smallint     NULL,
  product_description_lenght   smallint     NULL,
  product_photos_qty           tinyint      NULL,
  product_weight_g             int          NULL,
  product_length_cm            smallint     NULL,
  product_height_cm            smallint     NULL,
  product_width_cm             smallint     NULL,
  CONSTRAINT PK_clean_products PRIMARY KEY (product_id)
);

INSERT INTO clean.products
SELECT
  p.product_id,
  p.product_category_name,
  tr.product_category_name_english,
  TRY_CAST(p.product_name_lenght        AS smallint),
  TRY_CAST(p.product_description_lenght AS smallint),
  TRY_CAST(p.product_photos_qty         AS tinyint),
  TRY_CAST(p.product_weight_g           AS int),
  TRY_CAST(p.product_length_cm          AS smallint),
  TRY_CAST(p.product_height_cm          AS smallint),
  TRY_CAST(p.product_width_cm           AS smallint)
FROM raw.products p
LEFT JOIN raw.product_category_name_translation tr
  ON tr.product_category_name = p.product_category_name;

CREATE INDEX IX_clean_products_cat_en ON clean.products(product_category_name_english);

------------------------------------------------------------
-- 5) ORDERS (typed + handy flags)
------------------------------------------------------------
IF OBJECT_ID('clean.orders','U') IS NOT NULL DROP TABLE clean.orders;
CREATE TABLE clean.orders (
  order_id                       nvarchar(50) NOT NULL,
  customer_id                    nvarchar(50) NOT NULL,
  order_status                   nvarchar(50) NULL,
  order_purchase_timestamp       datetime2(0) NULL,
  order_approved_at              datetime2(0) NULL,
  order_delivered_carrier_date   datetime2(0) NULL,
  order_delivered_customer_date  datetime2(0) NULL,
  order_estimated_delivery_date  date         NULL,
  delivered_delay_days           int          NULL,  -- purchase -> delivered
  estimated_delay_days           int          NULL,  -- purchase -> estimated
  delivered_on_time              bit          NULL,  -- delivered_customer <= estimated
  CONSTRAINT PK_clean_orders PRIMARY KEY (order_id)
);

INSERT INTO clean.orders
SELECT
  o.order_id,
  o.customer_id,
  o.order_status,
  o.order_purchase_timestamp,
  o.order_approved_at,
  o.order_delivered_carrier_date,
  o.order_delivered_customer_date,
  o.order_estimated_delivery_date,
  CASE WHEN o.order_delivered_customer_date IS NOT NULL
       THEN DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date) END,
  CASE WHEN o.order_estimated_delivery_date IS NOT NULL
       THEN DATEDIFF(day, o.order_purchase_timestamp, CONVERT(datetime2(0), o.order_estimated_delivery_date)) END,
  CASE WHEN o.order_delivered_customer_date IS NOT NULL
            AND o.order_estimated_delivery_date IS NOT NULL
       THEN IIF(o.order_delivered_customer_date <= DATEADD(day, 1, CONVERT(datetime2(0), o.order_estimated_delivery_date)), 1, 0)
       END
FROM raw.orders o;

CREATE INDEX IX_clean_orders_customer ON clean.orders(customer_id);

------------------------------------------------------------
-- 6) ORDER_ITEMS
------------------------------------------------------------
IF OBJECT_ID('clean.order_items','U') IS NOT NULL DROP TABLE clean.order_items;
CREATE TABLE clean.order_items (
  order_id        nvarchar(50) NOT NULL,
  order_item_id   int          NOT NULL,
  product_id      nvarchar(50) NOT NULL,
  seller_id       nvarchar(50) NOT NULL,
  shipping_limit_date datetime2(0) NULL,
  price           decimal(12,2) NULL,
  freight_value   decimal(12,2) NULL,
  CONSTRAINT PK_clean_order_items PRIMARY KEY (order_id, order_item_id)
);

INSERT INTO clean.order_items
SELECT
  oi.order_id,
  oi.order_item_id,
  oi.product_id,
  oi.seller_id,
  oi.shipping_limit_date,
  oi.price,
  oi.freight_value
FROM raw.order_items oi;

CREATE INDEX IX_clean_order_items_product ON clean.order_items(product_id);
CREATE INDEX IX_clean_order_items_seller  ON clean.order_items(seller_id);

------------------------------------------------------------
-- 7) PAYMENTS (row-level; view will aggregate)
------------------------------------------------------------
IF OBJECT_ID('clean.payments','U') IS NOT NULL DROP TABLE clean.payments;
CREATE TABLE clean.payments (
  order_id            nvarchar(50) NOT NULL,
  payment_sequential  int          NOT NULL,
  payment_type        nvarchar(50) NULL,
  payment_installments int         NULL,
  payment_value       decimal(12,2) NULL,
  CONSTRAINT PK_clean_payments PRIMARY KEY (order_id, payment_sequential)
);

INSERT INTO clean.payments
SELECT order_id, payment_sequential, payment_type,
       payment_installments, payment_value
FROM raw.payments;

CREATE INDEX IX_clean_payments_order ON clean.payments(order_id);

------------------------------------------------------------
-- 8) REVIEWS (ya dedupeadas en RAW)
------------------------------------------------------------
IF OBJECT_ID('clean.reviews','U') IS NOT NULL DROP TABLE clean.reviews;
CREATE TABLE clean.reviews (
  review_id              nvarchar(50) NOT NULL,
  order_id               nvarchar(50) NOT NULL,
  review_score           int          NULL,
  review_comment_title   nvarchar(50) NULL,
  review_comment_message nvarchar(max) NULL,
  review_creation_date   datetime2(0) NULL,
  review_answer_timestamp datetime2(0) NULL,
  CONSTRAINT PK_clean_reviews PRIMARY KEY (review_id)
);

INSERT INTO clean.reviews
SELECT review_id, order_id, review_score,
       review_comment_title, review_comment_message,
       review_creation_date, review_answer_timestamp
FROM raw.reviews;

------------------------------------------------------------
-- FKs (después de insertar para evitar bloqueos)
------------------------------------------------------------
ALTER TABLE clean.orders
  WITH NOCHECK
  ADD CONSTRAINT FK_orders_customer
  FOREIGN KEY (customer_id) REFERENCES clean.customers(customer_id);

ALTER TABLE clean.order_items
  WITH NOCHECK
  ADD CONSTRAINT FK_items_order
  FOREIGN KEY (order_id) REFERENCES clean.orders(order_id);

ALTER TABLE clean.order_items
  WITH NOCHECK
  ADD CONSTRAINT FK_items_product
  FOREIGN KEY (product_id) REFERENCES clean.products(product_id);

ALTER TABLE clean.order_items
  WITH NOCHECK
  ADD CONSTRAINT FK_items_seller
  FOREIGN KEY (seller_id) REFERENCES clean.sellers(seller_id);

ALTER TABLE clean.payments
  WITH NOCHECK
  ADD CONSTRAINT FK_payments_order
  FOREIGN KEY (order_id) REFERENCES clean.orders(order_id);

ALTER TABLE clean.reviews
  WITH NOCHECK
  ADD CONSTRAINT FK_reviews_order
  FOREIGN KEY (order_id) REFERENCES clean.orders(order_id);

------------------------------------------------------------
-- QUICK QA
------------------------------------------------------------
SELECT 'orders' AS tbl, COUNT(*) AS rows FROM clean.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM clean.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM clean.payments
UNION ALL SELECT 'reviews', COUNT(*) FROM clean.reviews
UNION ALL SELECT 'customers', COUNT(*) FROM clean.customers
UNION ALL SELECT 'sellers', COUNT(*) FROM clean.sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM clean.geolocation
UNION ALL SELECT 'products', COUNT(*) FROM clean.products;
GO
