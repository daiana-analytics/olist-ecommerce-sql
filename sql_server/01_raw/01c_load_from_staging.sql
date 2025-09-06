/*
  Project   : Olist — SQL Server
  Script    : 01c_load_from_staging.sql
  Author    : Daiana Beltran
  Purpose   : Move data from staging tables (dbo.*_dataset) into RAW schema, idempotently
  RunOrder  : 01c
  Idempotent: Yes
*/

USE olist_sqlsrv;
SET NOCOUNT ON;

/* ========== OPTIONAL RESET (for clean reruns) ==========
   Set @reset_reviews = 1 only when you want to clear RAW before reloading.
   Commit it as 0 in your repo so it's safe by default.
*/
DECLARE @reset_reviews bit = 0;   -- change to 1 only for local clean reruns

IF @reset_reviews = 1 AND OBJECT_ID('raw.reviews','U') IS NOT NULL
BEGIN
  PRINT 'Resetting raw.reviews...';
  TRUNCATE TABLE raw.reviews;   -- If TRUNCATE fails due to FKs, use: DELETE FROM raw.reviews;
END
GO


/* ===================== ORDERS ===================== */
IF OBJECT_ID('dbo.olist_orders_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.orders (
    order_id, customer_id, order_status,
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
  )
  SELECT
    s.order_id, s.customer_id, s.order_status,
    TRY_CONVERT(datetime2(0), NULLIF(s.order_purchase_timestamp,'')),
    TRY_CONVERT(datetime2(0), NULLIF(s.order_approved_at,'')),
    TRY_CONVERT(datetime2(0), NULLIF(s.order_delivered_carrier_date,'')),
    TRY_CONVERT(datetime2(0), NULLIF(s.order_delivered_customer_date,'')),
    TRY_CONVERT(date,        NULLIF(s.order_estimated_delivery_date,''))
  FROM dbo.olist_orders_dataset s
  WHERE NOT EXISTS (SELECT 1 FROM raw.orders t WHERE t.order_id = s.order_id);

  DECLARE @rows_orders int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.orders: ', @rows_orders, ' rows');

  DROP TABLE dbo.olist_orders_dataset;
END
ELSE PRINT 'Skip: dbo.olist_orders_dataset does not exist';
GO


/* ===================== ORDER ITEMS ===================== */
IF OBJECT_ID('dbo.olist_order_items_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.order_items (
    order_id, order_item_id, product_id, seller_id,
    shipping_limit_date, price, freight_value
  )
  SELECT
    s.order_id,
    TRY_CAST(s.order_item_id AS int),
    s.product_id,
    s.seller_id,
    TRY_CONVERT(datetime2(0), NULLIF(s.shipping_limit_date,'')),
    TRY_CAST(REPLACE(s.price,',','.') AS decimal(12,2)),
    TRY_CAST(REPLACE(s.freight_value,',','.') AS decimal(12,2))
  FROM dbo.olist_order_items_dataset s
  WHERE NOT EXISTS (
    SELECT 1 FROM raw.order_items t
    WHERE t.order_id = s.order_id
      AND t.order_item_id = TRY_CAST(s.order_item_id AS int)
  );

  DECLARE @rows_order_items int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.order_items: ', @rows_order_items, ' rows');

  DROP TABLE dbo.olist_order_items_dataset;
END
ELSE PRINT 'Skip: dbo.olist_order_items_dataset does not exist';
GO


/* ===================== PAYMENTS ===================== */
IF OBJECT_ID('dbo.olist_order_payments_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.payments (
    order_id, payment_sequential, payment_type,
    payment_installments, payment_value
  )
  SELECT
    s.order_id,
    TRY_CAST(s.payment_sequential   AS int),
    s.payment_type,
    TRY_CAST(s.payment_installments AS int),
    TRY_CAST(REPLACE(s.payment_value,',','.') AS decimal(12,2))
  FROM dbo.olist_order_payments_dataset s
  WHERE NOT EXISTS (
    SELECT 1 FROM raw.payments t
    WHERE t.order_id = s.order_id
      AND t.payment_sequential = TRY_CAST(s.payment_sequential AS int)
  );

  DECLARE @rows_payments int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.payments: ', @rows_payments, ' rows');

  DROP TABLE dbo.olist_order_payments_dataset;
END
ELSE PRINT 'Skip: dbo.olist_order_payments_dataset does not exist';
GO


/* ===================== REVIEWS (dedup) ===================== */
IF OBJECT_ID('dbo.olist_order_reviews_dataset','U') IS NOT NULL
BEGIN
  ;WITH src AS (
    SELECT
      r.review_id,
      r.order_id,
      TRY_CAST(r.review_score AS int) AS review_score,
      r.review_comment_title,
      r.review_comment_message,
      TRY_CONVERT(datetime2(0), NULLIF(r.review_creation_date,''))     AS review_creation_date,
      TRY_CONVERT(datetime2(0), NULLIF(r.review_answer_timestamp,''))  AS review_answer_timestamp,
      ROW_NUMBER() OVER (
        PARTITION BY r.review_id
        ORDER BY
          TRY_CONVERT(datetime2(0), NULLIF(r.review_answer_timestamp,'')) DESC,
          TRY_CONVERT(datetime2(0), NULLIF(r.review_creation_date,''))  DESC,
          r.order_id ASC    -- deterministic tiebreaker
      ) AS rn
    FROM dbo.olist_order_reviews_dataset r
  )
  INSERT INTO raw.reviews (
    review_id, order_id, review_score,
    review_comment_title, review_comment_message,
    review_creation_date, review_answer_timestamp
  )
  SELECT s.review_id, s.order_id, s.review_score,
         s.review_comment_title, s.review_comment_message,
         s.review_creation_date, s.review_answer_timestamp
  FROM src s
  WHERE s.rn = 1
    AND NOT EXISTS (SELECT 1 FROM raw.reviews t WHERE t.review_id = s.review_id);

  DECLARE @rows_reviews int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.reviews: ', @rows_reviews, ' rows');

  -- optional: comment this DROP if you prefer to review the staging first
  DROP TABLE dbo.olist_order_reviews_dataset;
END
ELSE PRINT 'Skip: dbo.olist_order_reviews_dataset does not exist';
GO


/* ===================== CUSTOMERS ===================== */
IF OBJECT_ID('dbo.olist_customers_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.customers (
    customer_id, customer_unique_id, customer_zip_code_prefix,
    customer_city, customer_state
  )
  SELECT
    s.customer_id,
    s.customer_unique_id,
    TRY_CAST(s.customer_zip_code_prefix AS int),
    s.customer_city,
    s.customer_state
  FROM dbo.olist_customers_dataset s
  WHERE NOT EXISTS (SELECT 1 FROM raw.customers t WHERE t.customer_id = s.customer_id);

  DECLARE @rows_customers int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.customers: ', @rows_customers, ' rows');

  DROP TABLE dbo.olist_customers_dataset;
END
ELSE PRINT 'Skip: dbo.olist_customers_dataset does not exist';
GO


/* ===================== SELLERS ===================== */
IF OBJECT_ID('dbo.olist_sellers_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.sellers (
    seller_id, seller_zip_code_prefix, seller_city, seller_state
  )
  SELECT
    s.seller_id,
    TRY_CAST(s.seller_zip_code_prefix AS int),
    s.seller_city,
    s.seller_state
  FROM dbo.olist_sellers_dataset s
  WHERE NOT EXISTS (SELECT 1 FROM raw.sellers t WHERE t.seller_id = s.seller_id);

  DECLARE @rows_sellers int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.sellers: ', @rows_sellers, ' rows');

  DROP TABLE dbo.olist_sellers_dataset;
END
ELSE PRINT 'Skip: dbo.olist_sellers_dataset does not exist';
GO


/* ===================== GEOLOCATION ===================== */
IF OBJECT_ID('dbo.olist_geolocation_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.geolocation (
    geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
    geolocation_city, geolocation_state
  )
  SELECT
    TRY_CAST(s.geolocation_zip_code_prefix AS int),
    TRY_CAST(REPLACE(s.geolocation_lat,',','.') AS float),
    TRY_CAST(REPLACE(s.geolocation_lng,',','.') AS float),
    s.geolocation_city,
    s.geolocation_state
  FROM dbo.olist_geolocation_dataset s
  WHERE NOT EXISTS (
    SELECT 1 FROM raw.geolocation t
    WHERE t.geolocation_zip_code_prefix = TRY_CAST(s.geolocation_zip_code_prefix AS int)
      AND t.geolocation_city  = s.geolocation_city
      AND t.geolocation_state = s.geolocation_state
  );

  DECLARE @rows_geo int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.geolocation: ', @rows_geo, ' rows');

  DROP TABLE dbo.olist_geolocation_dataset;
END
ELSE PRINT 'Skip: dbo.olist_geolocation_dataset does not exist';
GO


/* ===================== PRODUCTS ===================== */
IF OBJECT_ID('dbo.olist_products_dataset','U') IS NOT NULL
BEGIN
  INSERT INTO raw.products (
    product_id, product_category_name, product_name_lenght,
    product_description_lenght, product_photos_qty,
    product_weight_g, product_length_cm, product_height_cm, product_width_cm
  )
  SELECT
    s.product_id,
    s.product_category_name,
    TRY_CAST(s.product_name_lenght        AS int),
    TRY_CAST(s.product_description_lenght AS int),
    TRY_CAST(s.product_photos_qty         AS int),
    TRY_CAST(s.product_weight_g           AS int),
    TRY_CAST(s.product_length_cm          AS int),
    TRY_CAST(s.product_height_cm          AS int),
    TRY_CAST(s.product_width_cm           AS int)
  FROM dbo.olist_products_dataset s
  WHERE NOT EXISTS (SELECT 1 FROM raw.products t WHERE t.product_id = s.product_id);

  DECLARE @rows_products int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.products: ', @rows_products, ' rows');

  DROP TABLE dbo.olist_products_dataset;
END
ELSE PRINT 'Skip: dbo.olist_products_dataset does not exist';
GO

/* ========== CATEGORY TRANSLATION (rename if needed, then load) ========== */
IF OBJECT_ID('dbo.product_category_name_translation','U') IS NOT NULL
BEGIN
  -- 1) Common case: the Import Wizard created column1/column2
  IF COL_LENGTH('dbo.product_category_name_translation', 'column1') IS NOT NULL
    EXEC sp_rename 'dbo.product_category_name_translation.column1',
                   'product_category_name', 'COLUMN';
  IF COL_LENGTH('dbo.product_category_name_translation', 'column2') IS NOT NULL
    EXEC sp_rename 'dbo.product_category_name_translation.column2',
                   'product_category_name_english', 'COLUMN';

  -- 2) Fallback: if expected names are still missing, rename the first two columns dynamically
  IF COL_LENGTH('dbo.product_category_name_translation', 'product_category_name') IS NULL
     OR COL_LENGTH('dbo.product_category_name_translation', 'product_category_name_english') IS NULL
  BEGIN
    DECLARE @c1 sysname, @c2 sysname;

    SELECT @c1 = name
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.product_category_name_translation')
    ORDER BY column_id
    OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

    -- Alternative if your version doesn't support OFFSET:
    -- SELECT TOP (1) @c1 = name FROM sys.columns
    -- WHERE object_id = OBJECT_ID('dbo.product_category_name_translation')
    -- ORDER BY column_id;

    SELECT TOP (1) @c2 = name
    FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.product_category_name_translation')
      AND name <> @c1
    ORDER BY column_id;

    IF @c1 IS NOT NULL AND @c1 <> N'product_category_name'
    BEGIN
      DECLARE @old1 sysname =
        CONCAT(N'dbo.product_category_name_translation.', QUOTENAME(@c1));
      EXEC sp_rename @old1, N'product_category_name', 'COLUMN';
    END;

    IF @c2 IS NOT NULL AND @c2 <> N'product_category_name_english'
    BEGIN
      DECLARE @old2 sysname =
        CONCAT(N'dbo.product_category_name_translation.', QUOTENAME(@c2));
      EXEC sp_rename @old2, N'product_category_name_english', 'COLUMN';
    END;
  END;  -- END fallback

  -- 3) Load into RAW (dedupe on product_category_name)
  INSERT INTO raw.product_category_name_translation (
    product_category_name, product_category_name_english
  )
  SELECT s.product_category_name, s.product_category_name_english
  FROM dbo.product_category_name_translation s
  WHERE NOT EXISTS (
    SELECT 1
    FROM raw.product_category_name_translation t
    WHERE t.product_category_name = s.product_category_name
  );

  DECLARE @rows_cat int = @@ROWCOUNT;
  PRINT CONCAT('Inserted into raw.product_category_name_translation: ', @rows_cat, ' rows');

  -- 4) Optional: drop the staging table if you no longer need it
  DROP TABLE dbo.product_category_name_translation;
END
ELSE PRINT 'Skip: dbo.product_category_name_translation does not exist';
GO

/* ===================== QUICK QA ===================== */
SELECT 'orders'                 AS tbl, COUNT(*) AS rows FROM raw.orders
UNION ALL SELECT 'order_items',                COUNT(*) FROM raw.order_items
UNION ALL SELECT 'payments',                   COUNT(*) FROM raw.payments
UNION ALL SELECT 'reviews',                    COUNT(*) FROM raw.reviews
UNION ALL SELECT 'customers',                  COUNT(*) FROM raw.customers
UNION ALL SELECT 'sellers',                    COUNT(*) FROM raw.sellers
UNION ALL SELECT 'geolocation',                COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'products',                   COUNT(*) FROM raw.products
UNION ALL SELECT 'category_translation',       COUNT(*) FROM raw.product_category_name_translation;
GO

/* ==== VERIFY: category translation in RAW ==== */
IF OBJECT_ID('raw.product_category_name_translation','U') IS NOT NULL
BEGIN
  SELECT COUNT(*) AS rows_cat
  FROM raw.product_category_name_translation;

  SELECT TOP (10)
         product_category_name,
         product_category_name_english
  FROM raw.product_category_name_translation
  ORDER BY product_category_name;
END
ELSE
  PRINT 'raw.product_category_name_translation is missing';
GO
