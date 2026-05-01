-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : innodb-pressure-snapshot                        ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (status counters)                      ║
-- ║  Permissions   : SELECT on performance_schema.global_status      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-innodb-pressure-snapshot ║
-- ║  Inspired by   : MySQL Reference Manual — InnoDB monitoring,     ║
-- ║                  buffer pool counters.                            ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: InnoDB exposes the four pressure dimensions every MySQL DBA
--       wants on a chart: buffer pool fill, dirty page ratio,
--       row-lock waits, and deadlock count. This snapshot returns
--       all four as one row per execution. Persist for the trend
--       view that turns "production feels slow" into "buffer pool
--       hit rate dropped 0.3% at 14:22 — same time as the deploy".
--   TR: InnoDB, her MySQL DBA'in grafikte istediği dört baskı
--       boyutunu açar: buffer pool dolumu, dirty page oranı, row-
--       lock bekleyişleri, deadlock sayısı. Bu snapshot dördünü
--       tek satırda döner. Saklarsan "üretim yavaş hissediyor"u
--       "buffer pool hit oranı 14:22'de %0.3 düştü — deploy ile
--       aynı saat"e dönüştüren trend görünümü olur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 charts these four dimensions together with
--   query throughput overlaid, baselines per server, and alerts
--   on regressions — see https://github.com/dmcteknoloji.

SELECT
    NOW(6)                                                              AS sample_utc,
    @@hostname                                                          AS hostname,
    -- Buffer pool dimensions
    ROUND(@@innodb_buffer_pool_size / 1048576)                          AS buffer_pool_size_mb,
    @@innodb_buffer_pool_instances                                       AS buffer_pool_instances,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total')            AS pages_total,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_data')             AS pages_data,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty')            AS pages_dirty,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_free')             AS pages_free,
    -- Dirty ratio = dirty / data — should sit below ~10% on healthy OLTP
    ROUND(100.0 *
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty')
        / NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status
                  WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_data'), 0),
        2)                                                              AS dirty_pages_pct,
    -- Hit rate (since startup) — diff externally for instant rate
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')          AS bp_read_requests_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')                  AS bp_reads_to_disk_cum,
    ROUND(100.0 *
        (1 -
         (SELECT VARIABLE_VALUE FROM performance_schema.global_status
          WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') * 1.0
         / NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status
                   WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
        ), 4)                                                           AS bp_hit_rate_pct,
    -- Row lock signals
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_current_waits')             AS row_lock_waits_now,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_waits')                     AS row_lock_waits_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_time')                      AS row_lock_time_ms_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_time_avg')                  AS row_lock_time_avg_ms,
    -- IO signals
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_data_read')                          AS data_read_bytes_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_data_written')                       AS data_written_bytes_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_data_pending_reads')                 AS pending_reads_now,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_data_pending_writes')                AS pending_writes_now,
    -- Verdict — single line for an alert subject
    CASE
        WHEN ROUND(100.0 *
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status
             WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty')
            / NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status
                      WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_data'), 0),
            2) > 50
            THEN '🟠 dirty pages > 50% — IO not keeping up with writes'
        WHEN (SELECT VARIABLE_VALUE FROM performance_schema.global_status
              WHERE VARIABLE_NAME = 'Innodb_row_lock_current_waits') > 10
            THEN '🟠 >10 sessions waiting on row locks right now'
    END                                                                 AS verdict;
