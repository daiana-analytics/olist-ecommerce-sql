# 00_environment — SQL Server

Sets up the base environment for the **Olist** project in SQL Server and prints a technical snapshot of the model.

## What it does
- Creates database `olist_sqlsrv` (collation `Latin1_General_100_CI_AI_SC`) and schemas `raw`, `clean`, `bi`.
- Keeps recovery model `SIMPLE` (portfolio-friendly).
- Outputs a **model snapshot**: tables/views, PKs, FKs, dependencies, and Graphviz-style edges.

## Files
- `00_create_database_and_schemas.sql` — Creates DB + schemas (idempotent).
- `00z_model_snapshot.sql` — Read-only report of the model (idempotent).

## Requirements
- SQL Server 2019+ (or Azure SQL DB), SSMS or Azure Data Studio.

## Run (order)
```sql
-- 1) Create DB and schemas
:r .\00_create_database_and_schemas.sql

-- 2) Model snapshot
USE olist_sqlsrv;
GO
:r .\00z_model_snapshot.sql

## Expected outputs (summary)

- **Database & schemas:** `olist_sqlsrv` created with collation `Latin1_General_100_CI_AI_SC`; schemas `raw`, `clean`, `bi`.
- **Grids:**
  1. Row counts
  2. Objects & columns
  3. PKs in `clean`
  4. FKs to/from `clean`
  5. View dependencies in `quality`/`bi`
  6. Graphviz edges for a quick ER diagram
