# 00_environment — SQL Server

Configura el entorno base para el proyecto **Olist** en SQL Server e imprime un snapshot técnico del modelo.

## Qué hace

- Crea la base de datos `olist_sqlsrv` con collation `Latin1_General_100_CI_AI_SC` y los esquemas `raw`, `clean`, `bi`.
- Mantiene el recovery model en `SIMPLE`, amigable para portfolio.
- Genera un **snapshot del modelo**: tablas/vistas, PKs, FKs, dependencias y edges estilo Graphviz.

## Archivos

- `00_create_database_and_schemas.sql` — Crea la base de datos y los esquemas. Idempotente.
- `00z_model_snapshot.sql` — Reporte read-only del modelo. Idempotente.

## Requisitos

- SQL Server 2019+ o Azure SQL DB, SSMS o Azure Data Studio.

## Ejecución (orden)

```sql
-- 1) Crear base de datos y esquemas
:r .\00_create_database_and_schemas.sql

-- 2) Snapshot del modelo
USE olist_sqlsrv;
GO
:r .\00z_model_snapshot.sql
```

## Salidas esperadas (resumen)

- **Base de datos y esquemas:** `olist_sqlsrv` creada con collation `Latin1_General_100_CI_AI_SC`; esquemas `raw`, `clean`, `bi`.
- **Grids:**
  1. Conteos de filas
  2. Objetos y columnas
  3. PKs en `clean`
  4. FKs hacia/desde `clean`
  5. Dependencias de vistas en `quality`/`bi`
  6. Edges Graphviz para un diagrama ER rápido




