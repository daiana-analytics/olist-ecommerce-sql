/*------------------------------------------------------------------------------
  Project : Olist - SQL Server Migration
  Script  : 00_create_database_and_schemas.sql
  Author  : Daiana Beltran
  Purpose : Create database and layered schemas (raw, clean, bi)
  RunOrder: 00
  Idempotent: Yes
------------------------------------------------------------------------------*/
SET NOCOUNT ON;
GO

-- Start in master to create/check the database
USE master;
GO

-- Create DB if not exists
IF DB_ID(N'olist_sqlsrv') IS NULL
BEGIN
    PRINT N'Creating database [olist_sqlsrv]...';
    CREATE DATABASE olist_sqlsrv
      COLLATE Latin1_General_100_CI_AI_SC;  -- case/accent-insensitive
END
ELSE
BEGIN
    PRINT N'Database [olist_sqlsrv] already exists. Skipping creation.';
END
GO

-- Keep SIMPLE recovery for a lightweight, portfolio database.
-- In production you'd likely use FULL for point-in-time recovery
ALTER DATABASE olist_sqlsrv SET RECOVERY SIMPLE WITH NO_WAIT;
GO

-- Work inside our DB
USE olist_sqlsrv;
GO

-- Create schemas if not exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'raw')
    EXEC('CREATE SCHEMA raw AUTHORIZATION dbo;');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'clean')
    EXEC('CREATE SCHEMA clean AUTHORIZATION dbo;');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'bi')
    EXEC('CREATE SCHEMA bi AUTHORIZATION dbo;');
GO

-- Quick checks
SELECT name AS db_name, collation_name
FROM sys.databases WHERE name = N'olist_sqlsrv';

SELECT name AS schema_name
FROM sys.schemas
WHERE name IN (N'raw', N'clean', N'bi')
ORDER BY name;
GO
