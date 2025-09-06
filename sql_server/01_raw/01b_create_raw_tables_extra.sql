/*──────────────────────────────────────────────────────────────────────────────
  Project : Olist – SQL Server Migration
  Script  : 01b_create_raw_tables_extra.sql
  Author  : Daiana Beltrán
  Purpose : Create remaining RAW tables (geolocation, products, category map).
  Run Order: 01b
  Idempotent: Yes
──────────────────────────────────────────────────────────────────────────────*/
SET NOCOUNT ON;
USE olist_sqlsrv;
GO

-- GEOLOCATION (no PK: hay muchas filas por mismo ZIP)
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

-- PRODUCTS
IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products (
        product_id                   VARCHAR(50)  NOT NULL PRIMARY KEY,
        product_category_name        VARCHAR(100) NULL,
        product_name_lenght          INT          NULL, -- (sic) nombre del dataset
        product_description_lenght   INT          NULL,
        product_photos_qty           INT          NULL,
        product_weight_g             INT          NULL,
        product_length_cm            INT          NULL,
        product_height_cm            INT          NULL,
        product_width_cm             INT          NULL
    );
END
GO

-- CATEGORY TRANSLATION (pt -> en)
IF OBJECT_ID(N'raw.product_category_name_translation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.product_category_name_translation (
        product_category_name         VARCHAR(100) NOT NULL,
        product_category_name_english VARCHAR(100) NOT NULL
    );
END
GO

-- Quick check
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = N'raw'
ORDER BY t.name;
GO
