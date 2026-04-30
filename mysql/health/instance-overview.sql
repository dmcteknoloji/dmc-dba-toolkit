-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : instance-overview                               ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (system variables + status counters)   ║
-- ║  Permissions   : standard SELECT — no special grants needed      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-instance-overview║
-- ║  Inspired by   : MySQL Reference Manual — Server Status Variables║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-03-15                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- One-screen summary of this MySQL server: identity (version, edition,
-- read-only mode), workload (connections, slow queries, queries per
-- second proxy), and InnoDB headline metrics (buffer pool, dirty pages).
--
-- Result is a single union-shaped table with a `section` discriminator,
-- ready for dashboards or CSV export.

SELECT * FROM (
    -- ── IDENTITY ────────────────────────────────────────────────
    SELECT 'IDENTITY' AS section, 'version' AS metric,
           @@version  AS value, NULL AS note
    UNION ALL
    SELECT 'IDENTITY', 'version_compile_os', @@version_compile_os, NULL
    UNION ALL
    SELECT 'IDENTITY', 'hostname', @@hostname, NULL
    UNION ALL
    SELECT 'IDENTITY', 'server_id', CAST(@@server_id AS CHAR), NULL
    UNION ALL
    SELECT 'IDENTITY', 'read_only', IF(@@read_only, 'ON', 'OFF'),
           IF(@@read_only, 'this server is read-only — likely a replica', NULL)
    UNION ALL
    SELECT 'IDENTITY', 'super_read_only', IF(@@super_read_only, 'ON', 'OFF'), NULL
    UNION ALL
    SELECT 'IDENTITY', 'sql_mode', @@sql_mode, NULL
    UNION ALL
    SELECT 'IDENTITY', 'time_zone', @@time_zone, NULL

    -- ── UPTIME ──────────────────────────────────────────────────
    UNION ALL
    SELECT 'UPTIME', 'uptime_seconds',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime'

    -- ── WORKLOAD ────────────────────────────────────────────────
    UNION ALL
    SELECT 'WORKLOAD', 'threads_connected',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'
    UNION ALL
    SELECT 'WORKLOAD', 'threads_running',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_running'
    UNION ALL
    SELECT 'WORKLOAD', 'max_used_connections',
           CAST(VARIABLE_VALUE AS CHAR),
           CONCAT('limit: ', CAST(@@max_connections AS CHAR))
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Max_used_connections'
    UNION ALL
    SELECT 'WORKLOAD', 'slow_queries',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Slow_queries'
    UNION ALL
    SELECT 'WORKLOAD', 'aborted_clients',
           CAST(VARIABLE_VALUE AS CHAR),
           'connections aborted because the client died — high values often indicate timeouts'
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Aborted_clients'

    -- ── INNODB ──────────────────────────────────────────────────
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_size_mb',
           CAST(ROUND(@@innodb_buffer_pool_size / 1024 / 1024) AS CHAR), NULL
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_pages_total',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total'
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_pages_dirty',
           CAST(VARIABLE_VALUE AS CHAR), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty'
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_hit_rate_pct',
           (SELECT CAST(ROUND(100.0 * (1 - read_misses / NULLIF(reads, 0)), 2) AS CHAR)
            FROM (SELECT
                    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
                     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS read_misses,
                    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
                     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS reads
                 ) AS bp),
           'higher is better; <99% on busy OLTP usually indicates undersized buffer pool'
) AS t
ORDER BY FIELD(section, 'IDENTITY', 'UPTIME', 'WORKLOAD', 'INNODB');
