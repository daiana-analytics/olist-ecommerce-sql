/*------------------------------------------------------------------------------
  Project : Olist - SQL Server
  Script  : 01_create_raw_tables.sql
  Author  : Daiana Beltran
  Purpose : Create RAW tables (orders, order_items, payments, reviews,
            customers, sellers). Complements 01b (geo/products/translation).
  RunOrder: 01
  Idempotent: Yes
------------------------------------------------------------------------------*/
SET NOCOUNT ON;
USE olist_sqlsrv;
GO

-- ORDERS ----------------------------------------------------------------------
IF OBJECT_ID(N'raw.orders', N'U') IS NULL
BEGIN
  CREATE TABLE raw.orders (
    order_id                      VARCHAR(50)  NOT NULL,
    customer_id                   VARCHAR(50)  NOT NULL,
    order_status                  VARCHAR(20)  NOT NULL,
    order_purchase_timestamp      DATETIME2(0) NOT NULL,
    order_approved_at             DATETIME2(0) NULL,
    order_delivered_carrier_date  DATETIME2(0) NULL,
    order_delivered_customer_date DATETIME2(0) NULL,
    order_estimated_delivery_date DATE         NOT NULL,
    CONSTRAINT PK_raw_orders PRIMARY KEY (order_id)
  );
END
GO

-- ORDER ITEMS -----------------------------------------------------------------
IF OBJECT_ID(N'raw.order_items', N'U') IS NULL
BEGIN
  CREATE TABLE raw.order_items (
    order_id            VARCHAR(50)   NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          VARCHAR(50)   NOT NULL,
    seller_id           VARCHAR(50)   NOT NULL,
    shipping_limit_date DATETIME2(0)  NULL,
    price               DECIMAL(12,2) NOT NULL,
    freight_value       DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_raw_order_items PRIMARY KEY (order_id, order_item_id)
  );
END
GO

-- PAYMENTS --------------------------------------------------------------------
IF OBJECT_ID(N'raw.payments', N'U') IS NULL
BEGIN
  CREATE TABLE raw.payments (
    order_id             VARCHAR(50)   NOT NULL,
    payment_sequential   INT           NOT NULL,
    payment_type         VARCHAR(30)   NOT NULL,
    payment_installments INT           NOT NULL,
    payment_value        DECIMAL(12,2) NOT NULL
  );
END
GO

/* === Ensure PK on raw.payments (idempotent) === */
IF OBJECT_ID(N'raw.payments', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints
    WHERE [type] = 'PK'
      AND parent_object_id = OBJECT_ID(N'raw.payments', N'U')
)
BEGIN
    ALTER TABLE raw.payments
      ADD CONSTRAINT PK_raw_payments
      PRIMARY KEY (order_id, payment_sequential);
END
GO

-- REVIEWS ---------------------------------------------------------------------
IF OBJECT_ID(N'raw.reviews', N'U') IS NULL
BEGIN
  CREATE TABLE raw.reviews (
    review_id               VARCHAR(50)  NOT NULL,
    order_id                VARCHAR(50)  NOT NULL,
    review_score            INT          NOT NULL,
    review_comment_title    VARCHAR(200) NULL,
    review_comment_message  VARCHAR(MAX) NULL,
    review_creation_date    DATETIME2(0) NULL,
    review_answer_timestamp DATETIME2(0) NULL,
    CONSTRAINT PK_raw_reviews PRIMARY KEY (review_id)
  );
END
GO

-- CUSTOMERS -------------------------------------------------------------------
IF OBJECT_ID(N'raw.customers', N'U') IS NULL
BEGIN
  CREATE TABLE raw.customers (
    customer_id              VARCHAR(50)  NOT NULL PRIMARY KEY,
    customer_unique_id       VARCHAR(50)  NULL,
    customer_zip_code_prefix INT          NULL,
    customer_city            VARCHAR(100) NULL,
    customer_state           VARCHAR(10)  NULL
  );
END
GO

-- SELLERS ---------------------------------------------------------------------
IF OBJECT_ID(N'raw.sellers', N'U') IS NULL
BEGIN
  CREATE TABLE raw.sellers (
    seller_id                VARCHAR(50)  NOT NULL PRIMARY KEY,
    seller_zip_code_prefix   INT          NULL,
    seller_city              VARCHAR(100) NULL,
    seller_state             VARCHAR(10)  NULL
  );
END
GO

/* === Helper indexes for BI reads (idempotent) === */

IF OBJECT_ID(N'raw.orders', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_orders_customer'
      AND object_id = OBJECT_ID(N'raw.orders')
)
    CREATE INDEX IX_raw_orders_customer ON raw.orders(customer_id);
GO

IF OBJECT_ID(N'raw.order_items', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_order_items_product'
      AND object_id = OBJECT_ID(N'raw.order_items')
)
    CREATE INDEX IX_raw_order_items_product ON raw.order_items(product_id);
GO

IF OBJECT_ID(N'raw.payments', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_payments_type'
      AND object_id = OBJECT_ID(N'raw.payments')
)
    CREATE INDEX IX_raw_payments_type ON raw.payments(payment_type);
GO

IF OBJECT_ID(N'raw.customers', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_customers_unique'
      AND object_id = OBJECT_ID(N'raw.customers')
)
    CREATE INDEX IX_raw_customers_unique ON raw.customers(customer_unique_id);
GO

-- Quick check (you can run this alone selecting it and pressing F5)
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = N'raw'
ORDER BY t.name;
GO

