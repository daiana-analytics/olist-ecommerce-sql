/*==============================================================================
  Project   : Olist – SQL Server Migration
  Script    : 01b_create_raw_tables_extra.sql
  Author    : Daiana Beltrán
  Purpose   : Create remaining RAW tables (geolocation, products, category map)
  Run Order : 01b
  Idempotent: Yes
==============================================================================*/
SET NOCOUNT ON;
USE olist_sqlsrv;
GO

-- Geolocation (no PK; multiple rows per ZIP)
IF OBJECT_ID(N'raw.geolocation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.geolocation (
        geolocation_zip_code_prefix INT          NOT NULL,
        geolocation_lat             FLOAT        NULL,
        geolocation_lng             FLOAT        NULL,
        geolocation_city            VARCHAR(100) NULL,
        geolocation_state           VARCHAR(10)  NULL
    );
END
GO

-- Products
IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products (
        product_id                   VARCHAR(50)  NOT NULL PRIMARY KEY,
        product_category_name        VARCHAR(100) NULL,
        product_name_lenght          INT          NULL, -- (sic) dataset spelling
        product_description_lenght   INT          NULL,
        product_photos_qty           INT          NULL,
        product_weight_g             INT          NULL,
        product_length_cm            INT          NULL,
        product_height_cm            INT          NULL,
        product_width_cm             INT          NULL
    );
END
GO

-- Category translation (pt -> en)
IF OBJECT_ID(N'raw.product_category_name_translation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.product_category_name_translation (
        product_category_name         VARCHAR(100) NOT NULL,
        product_category_name_english VARCHAR(100) NOT NULL
    );
END
GO

/* === Optional helper indexes for BI (idempotent) === */

-- Products by category
IF OBJECT_ID(N'raw.products', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_products_category'
      AND object_id = OBJECT_ID(N'raw.products')
)
    CREATE INDEX IX_raw_products_category ON raw.products(product_category_name);
GO

-- Category translation unique by PT name (guards duplicates)
IF OBJECT_ID(N'raw.product_category_name_translation', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UX_raw_category_translation_pt'
      AND object_id = OBJECT_ID(N'raw.product_category_name_translation')
)
    CREATE UNIQUE INDEX UX_raw_category_translation_pt
        ON raw.product_category_name_translation(product_category_name);
GO

-- Geolocation by ZIP prefix
IF OBJECT_ID(N'raw.geolocation', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'IX_raw_geolocation_zip'
      AND object_id = OBJECT_ID(N'raw.geolocation')
)
    CREATE INDEX IX_raw_geolocation_zip
        ON raw.geolocation(geolocation_zip_code_prefix);
GO

-- Quick check
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = N'raw'
ORDER BY t.name;
GO

