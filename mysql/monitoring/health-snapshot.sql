-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : health-snapshot                                 ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (designed for periodic execution)      ║
-- ║  Permissions   : SELECT on performance_schema, sys schema        ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-health-snapshot║
-- ║  Inspired by   : MySQL Reference Manual — Server Status Variables║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-30                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: A one-row, periodic snapshot for cron + a target table.
--       Connections, queries, slow queries, replica lag (if applier
--       is running), aborted clients, InnoDB row-lock waits, dirty
--       pages — the classic shortlist that any MySQL DBA wants on a
--       chart.
--   TR: Cron + hedef tablo için tek satırlık periyodik snapshot.
--       Bağlantılar, sorgular, yavaş sorgular, replica lag,
--       aborted istemciler, InnoDB row-lock bekleyişleri, dirty
--       page'ler — herhangi bir MySQL DBA'in grafikte istediği
--       klasik kısa liste.
--
-- Beyond this script / Bunun ötesinde:
--   For continuous, multi-instance monitoring with alerting,
--   persistence, dashboards, and AI-assisted findings, see
--   DMC's Sentinel DB 360 — https://github.com/dmcteknoloji

SELECT
    NOW(6)                                                       AS sample_utc,
    @@hostname                                                   AS hostname,
    @@server_id                                                  AS server_id,
    @@version                                                    AS version,
    -- Connection state
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Threads_connected')                  AS threads_connected,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Threads_running')                    AS threads_running,
    @@max_connections                                            AS max_connections,
    -- Throughput (cumulative — diff externally for rate)
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Questions')                          AS questions_cumulative,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_select')                         AS com_select_cumulative,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_insert')                         AS com_insert_cumulative,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_update')                         AS com_update_cumulative,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_delete')                         AS com_delete_cumulative,
    -- Health signals
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Slow_queries')                       AS slow_queries_cumulative,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Aborted_clients')                    AS aborted_clients_cumulative,
    -- InnoDB
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty')     AS innodb_dirty_pages,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_current_waits')      AS innodb_row_lock_waits_now,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Innodb_row_lock_time')               AS innodb_row_lock_time_cumulative,
    -- Replica lag (8.0+, returns NULL on standalone)
    (SELECT TIMESTAMPDIFF(
                SECOND,
                MAX(LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP),
                NOW(6))
     FROM performance_schema.replication_applier_status_by_worker)
                                                                 AS replica_lag_secs;
