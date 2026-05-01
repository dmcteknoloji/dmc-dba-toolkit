-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : table-bloat-estimate                            ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : storage                                         ║
-- ║  Impact        : 🟡 Medium  (joins pg_class with planner stats)   ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_class, pg_stats ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-table-bloat-est   ║
-- ║  Inspired by   : Greg Sabino Mullane's bloat estimation SQL,     ║
-- ║                  shared publicly via the Bucardo blog (2007+).   ║
-- ║                  Technique credited; query re-implemented here.  ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-01-04                                      ║
-- ║  Level         : 🦅 Expert   (output requires deep DMV / internals knowledge)      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Estimates table bloat using pg_class.relpages and pg_stats column
-- statistics. This is fast and runs against any production cluster
-- safely. It is an *estimate* — for ground truth, install the
-- pgstattuple extension and use pgstattuple_approx().
--
-- The estimation models the minimum number of pages a table "should"
-- occupy given its row count and average row width, then compares with
-- pg_class.relpages * 8 KB to flag excess.
--
-- High bloat ratios (>30%) on large tables are usually the signal that
-- autovacuum is running behind, not that the data itself is huge.
--
-- This query targets ordinary heap tables. Indexes have their own
-- bloat formula; see future v2.1 script index-bloat-estimate.

WITH constants AS (
    SELECT current_setting('block_size')::numeric AS bs,
           23                                     AS hdr,
           8                                      AS ma
),
columns_stats AS (
    SELECT
        s.schemaname,
        s.tablename,
        sum((1 - s.null_frac) * s.avg_width)                AS data_width,
        max(s.null_frac)                                     AS max_null_frac
    FROM pg_stats AS s
    WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
    GROUP BY s.schemaname, s.tablename
),
table_estimates AS (
    SELECT
        c.oid,
        n.nspname                                            AS schemaname,
        c.relname                                            AS tablename,
        c.reltuples,
        c.relpages,
        cs.data_width,
        constants.bs,
        constants.hdr,
        constants.ma,
        ceil(c.reltuples
             * (constants.hdr + cs.data_width
                + (constants.ma
                   - CASE
                       WHEN ((constants.hdr + cs.data_width) % constants.ma) = 0
                           THEN constants.ma
                       ELSE (constants.hdr + cs.data_width) % constants.ma
                     END))
             / (constants.bs - 24))                          AS expected_pages
    FROM pg_class                                            AS c
    JOIN pg_namespace                                        AS n ON n.oid = c.relnamespace
    JOIN columns_stats                                       AS cs
        ON cs.schemaname = n.nspname AND cs.tablename = c.relname
    CROSS JOIN constants
    WHERE c.relkind = 'r'
      AND c.reltuples > 100
)
SELECT
    schemaname,
    tablename,
    pg_size_pretty(relpages * bs)                            AS actual_size,
    pg_size_pretty(expected_pages * bs)                      AS expected_size,
    pg_size_pretty((relpages - expected_pages) * bs)         AS estimated_bloat,
    CASE
        WHEN relpages = 0 THEN 0
        ELSE round(100.0 * (relpages - expected_pages) / relpages, 1)
    END                                                      AS bloat_pct,
    round(reltuples)                                         AS row_count_estimate
FROM table_estimates
WHERE relpages > expected_pages
  AND (relpages - expected_pages) * bs > 10 * 1024 * 1024  -- ignore <10 MB savings
ORDER BY (relpages - expected_pages) DESC
LIMIT 25;
