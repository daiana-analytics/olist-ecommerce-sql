/* ===========================================================
   Project : Olist — SQL Server
   Script  : 00z_model_snapshot.sql
   Purpose : Model snapshot (tables/views, PKs, FKs, dependencies).
   Run     : USE olist_sqlsrv; GO  (SQL Server 2019+)
   Notes   : Read-only. Safe to re-run.
   =========================================================== */

USE olist_sqlsrv;
SET NOCOUNT ON;
GO

/* 0) Row counts by schema */
SELECT s.name AS [schema], t.name AS [table], p.rows
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE s.name IN ('raw','clean','quality','bi')
ORDER BY s.name, t.name;

/* 1) Objects and columns (tables and views) */
SELECT 
  otype = CASE WHEN t.object_id IS NOT NULL THEN 'TABLE' ELSE 'VIEW' END,
  s.name     AS schema_name,
  obj_name   = COALESCE(t.name, v.name),
  c.column_id,
  c.name     AS column_name,
  TYPE_NAME(c.user_type_id) AS data_type,
  c.max_length, c.precision, c.scale,
  c.is_nullable
FROM sys.schemas s
LEFT JOIN sys.tables t ON t.schema_id = s.schema_id
LEFT JOIN sys.views  v ON v.schema_id = s.schema_id
JOIN sys.columns c 
  ON c.object_id = COALESCE(t.object_id, v.object_id)
WHERE s.name IN ('clean','quality','bi')
ORDER BY otype, schema_name, obj_name, c.column_id;
GO

/* 2) Primary keys (PK) in CLEAN */
SELECT 
  schema_name = s.name,
  table_name  = t.name,
  pk_name     = kc.name,
  column_name = COL_NAME(ic.object_id, ic.column_id),
  ic.key_ordinal
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic 
  ON ic.object_id = kc.parent_object_id
 AND ic.index_id  = kc.unique_index_id
WHERE kc.[type] = 'PK'
  AND s.name = 'clean'
ORDER BY s.name, t.name, ic.key_ordinal;
GO

/* 3) Foreign keys (FK) — relationships in CLEAN */
SELECT 
  fk_schema   = sch.name,
  fk_name     = fk.name,
  parent_tbl  = CONCAT(schp.name, '.', tp.name),
  parent_col  = cp.name,
  ref_tbl     = CONCAT(schr.name, '.', tr.name),
  ref_col     = cr.name
FROM sys.foreign_keys fk
JOIN sys.schemas sch       ON sch.schema_id       = fk.schema_id
JOIN sys.tables tp         ON tp.object_id        = fk.parent_object_id
JOIN sys.schemas schp      ON schp.schema_id      = tp.schema_id
JOIN sys.tables tr         ON tr.object_id        = fk.referenced_object_id
JOIN sys.schemas schr      ON schr.schema_id      = tr.schema_id
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = fkc.referenced_column_id
WHERE schp.name = 'clean' OR schr.name = 'clean'
ORDER BY fk.name, fkc.constraint_column_id;
GO

/* 4) View dependencies (what each QUALITY/BI view references) */
SELECT 
  view_schema = s1.name,
  view_name   = v.name,
  referenced_schema = s2.name,
  referenced_object = o2.name,
  referenced_type   = o2.type_desc
FROM sys.views v
JOIN sys.schemas s1 ON s1.schema_id = v.schema_id
LEFT JOIN sys.sql_expression_dependencies d ON d.referencing_id = v.object_id
LEFT JOIN sys.objects o2 ON o2.object_id = d.referenced_id
LEFT JOIN sys.schemas s2 ON s2.schema_id = o2.schema_id
WHERE s1.name IN ('quality','bi')
ORDER BY view_schema, view_name, referenced_schema, referenced_object;
GO

/* 5) (Optional) Graphviz-like edges for a quick ER diagram */
SELECT DISTINCT
  dot_edge = CONCAT(schp.name, '.', tp.name, ' -> ', schr.name, '.', tr.name, ';')
FROM sys.foreign_keys fk
JOIN sys.tables tp ON tp.object_id = fk.parent_object_id
JOIN sys.schemas schp ON schp.schema_id = tp.schema_id
JOIN sys.tables tr ON tr.object_id = fk.referenced_object_id
JOIN sys.schemas schr ON schr.schema_id = tr.schema_id
WHERE schp.name = 'clean' OR schr.name = 'clean'
ORDER BY dot_edge;
GO
