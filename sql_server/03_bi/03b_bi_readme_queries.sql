/*==============================================================================
  Project  : Olist - SQL Server
  Script   : 03b_bi_readme_queries.sql
  Purpose  : Run BI showcase queries for README screenshots.
  Context  : Assumes 03a_publish_bi_views.sql and 99c_quality_fixes.sql were run.
  Author   : Daiana Beltran
  Notes    : Read-only. Safe to re-run.
==============================================================================*/

USE olist_sqlsrv;
SET NOCOUNT ON;
GO

/* 1) KPI summary — single-row KPI */
SELECT * FROM bi.v_kpi_summary;
GO

/* 2) Daily sales — compact sample */
SELECT TOP (15) *
FROM bi.v_daily_sales
ORDER BY purchase_date;
GO

/* 3) Payment mix — business-friendly percentages */
SELECT payment_type, txn_count, amount, pct_txn, pct_amount
FROM bi.v_payment_mix
ORDER BY pct_amount DESC;
GO

/* 4) Late orders — quick sample */
SELECT TOP (15) *
FROM bi.v_late_orders
ORDER BY lead_time_days DESC;
GO

/* 5) Lead-time distribution — small sample */
SELECT TOP (15) purchase_date, lead_time_days
FROM bi.v_delivery_lead_time
ORDER BY lead_time_days DESC;
GO

