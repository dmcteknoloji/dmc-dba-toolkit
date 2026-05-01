-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : top-queries                                     ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (single view scan, milliseconds)       ║
-- ║  Permissions   : pg_read_all_stats (or superuser)                ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-top-queries       ║
-- ║  Inspired by   : pg_stat_statements official docs (postgresql.org)║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-10-08                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   pg_stat_statements üzerinden en çok zaman tüketen sorguları döner.
--   PG 13+ kolon adları (total_exec_time, planning_time vb.) kullanılır.
--   Pre-flight: pg_stat_statements extension yüklü olmalı; managed
--   servislerde (RDS, Aurora, Cloud SQL) parametre grubuyla aktif edilir.
--
-- Returns the top queries by cumulative execution time from the
-- pg_stat_statements extension. Requires the extension to be installed
-- and shared_preload_libraries to include 'pg_stat_statements' (default
-- on most managed services like RDS, Aurora, Cloud SQL).
--
-- Column names changed in PG 13: total_time -> total_exec_time, and the
-- view added planning columns. This script targets the modern shape
-- (PG 13+). For older versions, see vendor docs and downgrade locally.
--
-- The view's rows are normalized by query_id (PG 14+) or query text
-- (older), so different parameter values collapse into one row. This is
-- usually what you want; if you need per-call breakdowns, look at
-- pg_stat_activity for live sessions instead.
--
-- Pre-flight check:
--   SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';
-- If empty: CREATE EXTENSION pg_stat_statements; (requires superuser)

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements') THEN
        RAISE NOTICE 'pg_stat_statements is not installed in this database. Run: CREATE EXTENSION pg_stat_statements;';
    END IF;
END$$;

SELECT
    row_number() OVER (ORDER BY pss.total_exec_time DESC)        AS rank,
    pss.queryid,
    d.datname                                                    AS database_name,
    r.rolname                                                    AS role_name,
    pss.calls,
    round(pss.total_exec_time::numeric, 2)                       AS total_exec_ms,
    round((pss.total_exec_time / nullif(pss.calls, 0))::numeric, 2) AS avg_exec_ms,
    round(pss.min_exec_time::numeric, 2)                         AS min_exec_ms,
    round(pss.max_exec_time::numeric, 2)                         AS max_exec_ms,
    round(pss.stddev_exec_time::numeric, 2)                      AS stddev_exec_ms,
    pss.rows                                                     AS total_rows,
    pss.shared_blks_hit                                          AS shared_blks_hit,
    pss.shared_blks_read                                         AS shared_blks_read,
    round(
        (100.0 * pss.shared_blks_hit
         / nullif(pss.shared_blks_hit + pss.shared_blks_read, 0))::numeric,
        2
    )                                                            AS cache_hit_pct,
    -- Truncate query text for readability; full text remains in the view.
    left(pss.query, 200)                                         AS query_preview
FROM pg_stat_statements                                          AS pss
LEFT JOIN pg_database                                            AS d ON d.oid = pss.dbid
LEFT JOIN pg_roles                                               AS r ON r.oid = pss.userid
ORDER BY pss.total_exec_time DESC
LIMIT 25;
