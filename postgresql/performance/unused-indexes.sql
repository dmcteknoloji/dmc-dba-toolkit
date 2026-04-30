-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : unused-indexes                                  ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (catalog + pg_stat_user_indexes)       ║
-- ║  Permissions   : pg_read_all_stats; standard SELECT on catalogs  ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-unused-indexes    ║
-- ║  Inspired by   : pg_stat_user_indexes documentation              ║
-- ║                  (postgresql.org). Verdict bands are this        ║
-- ║                  toolkit's convention.                            ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-10                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Every index costs RAM (held in shared_buffers if hot), disk,    ║
-- ║  and write amplification on every UPDATE/INSERT. After a year   ║
-- ║  in production, most non-trivial schemas have indexes that look ║
-- ║  important and aren't being used. This script surfaces them —    ║
-- ║  but with the discipline to mark how recent the stats are, so   ║
-- ║  you don't drop an index three days after a node restart wiped  ║
-- ║  its counters.                                                   ║
-- ╚══════════════════════════════════════════════════════════════════╝

WITH stats_age AS (
    SELECT
        EXTRACT(epoch FROM (now() - stats_reset))::bigint AS reset_age_secs
    FROM pg_stat_database
    WHERE datname = current_database()
)
SELECT
    s.schemaname,
    s.relname                                              AS table_name,
    s.indexrelname                                         AS index_name,
    pg_size_pretty(pg_relation_size(s.indexrelid))         AS index_size,
    pg_relation_size(s.indexrelid)                         AS index_size_bytes,
    s.idx_scan                                             AS scans_since_reset,
    s.idx_tup_read                                         AS tuples_read,
    s.idx_tup_fetch                                        AS tuples_fetched,
    -- Stats reset age — the trump card. If your DB restarted last
    -- night, every index will look unused. Always sanity-check.
    age.reset_age_secs / 86400                             AS reset_age_days,
    CASE
        WHEN ix.indisunique
            THEN 'UNIQUE — required for the constraint, do not drop'
        WHEN ix.indisprimary
            THEN 'PRIMARY KEY — required, do not drop'
        WHEN s.idx_scan = 0 AND age.reset_age_secs < 7 * 86400
            THEN 'unused but stats < 7 days old — wait for a full week'
        WHEN s.idx_scan = 0
            THEN '🔴 0 scans since reset — strong drop candidate'
        WHEN s.idx_scan < 50
            THEN '🟠 fewer than 50 scans — review whether the queries still need it'
        ELSE '🟢 active'
    END                                                    AS verdict
FROM pg_stat_user_indexes  AS s
JOIN pg_index              AS ix ON ix.indexrelid = s.indexrelid
CROSS JOIN stats_age       AS age
WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY
    CASE
        WHEN ix.indisunique OR ix.indisprimary THEN 9
        WHEN s.idx_scan = 0 THEN 1
        WHEN s.idx_scan < 50 THEN 2
        ELSE 3
    END,
    pg_relation_size(s.indexrelid) DESC;
