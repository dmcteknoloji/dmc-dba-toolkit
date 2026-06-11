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
-- ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   MySQL server için tek-ekran özet: kimlik (sürüm, hostname, server_id,
--   read_only flag), uptime, iş yükü (threads_connected, slow_queries,
--   aborted_clients), InnoDB headline (buffer pool, dirty pages, hit rate).
--   read_only=ON → bu büyük olasılıkla replikadır.
--
-- One-screen summary of this MySQL server: identity (version, edition,
-- read-only mode), workload (connections, slow queries, queries per
-- second proxy), and InnoDB headline metrics (buffer pool, dirty pages).
--
-- Result is a single union-shaped table with a `section` discriminator,
-- ready for dashboards or CSV export.

SELECT * FROM (
    -- ── IDENTITY ────────────────────────────────────────────────
    -- Every branch CONVERTs its value to utf8mb4 so the UNION never trips over
    -- a latin1 system variable ( @@hostname, @@version_compile_os ) meeting a
    -- utf8mb3 literal — MySQL refuses to mix charsets across a UNION otherwise.
    SELECT 'IDENTITY' AS section, 'version' AS metric,
           CONVERT(@@version USING utf8mb4) AS value, NULL AS note
    UNION ALL
    SELECT 'IDENTITY', 'version_compile_os', CONVERT(@@version_compile_os USING utf8mb4), NULL
    UNION ALL
    SELECT 'IDENTITY', 'hostname', CONVERT(@@hostname USING utf8mb4), NULL
    UNION ALL
    SELECT 'IDENTITY', 'server_id', CONVERT(@@server_id USING utf8mb4), NULL
    UNION ALL
    SELECT 'IDENTITY', 'read_only', CONVERT(IF(@@read_only, 'ON', 'OFF') USING utf8mb4),
           IF(@@read_only, 'this server is read-only — likely a replica', NULL)
    UNION ALL
    SELECT 'IDENTITY', 'super_read_only', CONVERT(IF(@@super_read_only, 'ON', 'OFF') USING utf8mb4), NULL
    UNION ALL
    SELECT 'IDENTITY', 'sql_mode', CONVERT(@@sql_mode USING utf8mb4), NULL
    UNION ALL
    SELECT 'IDENTITY', 'time_zone', CONVERT(@@time_zone USING utf8mb4), NULL

    -- ── UPTIME ──────────────────────────────────────────────────
    UNION ALL
    SELECT 'UPTIME', 'uptime_seconds',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Uptime'

    -- ── WORKLOAD ────────────────────────────────────────────────
    UNION ALL
    SELECT 'WORKLOAD', 'threads_connected',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_connected'
    UNION ALL
    SELECT 'WORKLOAD', 'threads_running',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Threads_running'
    UNION ALL
    SELECT 'WORKLOAD', 'max_used_connections',
           CONVERT(VARIABLE_VALUE USING utf8mb4),
           CONCAT('limit: ', CAST(@@max_connections AS CHAR))
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Max_used_connections'
    UNION ALL
    SELECT 'WORKLOAD', 'slow_queries',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Slow_queries'
    UNION ALL
    SELECT 'WORKLOAD', 'aborted_clients',
           CONVERT(VARIABLE_VALUE USING utf8mb4),
           'connections aborted because the client died — high values often indicate timeouts'
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Aborted_clients'

    -- ── INNODB ──────────────────────────────────────────────────
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_size_mb',
           CONVERT(CAST(ROUND(@@innodb_buffer_pool_size / 1024 / 1024) AS CHAR) USING utf8mb4), NULL
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_pages_total',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total'
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_pages_dirty',
           CONVERT(VARIABLE_VALUE USING utf8mb4), NULL
    FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty'
    UNION ALL
    SELECT 'INNODB', 'buffer_pool_hit_rate_pct',
           CONVERT((SELECT CAST(ROUND(100.0 * (1 - read_misses / NULLIF(read_reqs, 0)), 2) AS CHAR)
            FROM (SELECT
                    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
                     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') AS read_misses,
                    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
                     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests') AS read_reqs
                 ) AS bp) USING utf8mb4),
           'higher is better; <99% on busy OLTP usually indicates undersized buffer pool'
) AS t
ORDER BY FIELD(section, 'IDENTITY', 'UPTIME', 'WORKLOAD', 'INNODB');
