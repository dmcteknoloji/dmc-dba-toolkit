-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : health-snapshot                                 ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (designed for periodic execution)      ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-health-snapshot║
-- ║  Inspired by   : Microsoft Learn — performance counters and DMV  ║
-- ║                  references for ongoing monitoring.               ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-30                                      ║
-- ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: A one-row snapshot you can run on a 1-minute schedule. Each
--       execution returns the headline metrics in a single timestamped
--       row, so a job + a target table = a poor man's monitoring
--       system. This is intentionally minimal. The toolkit's deeper
--       diagnostic scripts answer "what happened?" — this one feeds
--       the chart that tells you "when did it start?".
--   TR: Her dakika çalıştırılmak üzere tasarlanmış tek satır snapshot.
--       Bir job + hedef tablo = zavallı adamın monitoring sistemi.
--       Bilinçli olarak minimaldir. Toolkit'teki derin tanı scriptleri
--       "ne oldu?"yu cevaplar; bu script "ne zaman başladı?" sorusuna
--       cevap veren grafiği besler.
--
-- Beyond this script / Bunun ötesinde:
--   For continuous, multi-instance monitoring with alerting,
--   persistence, dashboards, and AI-assisted findings, see
--   DMC's Sentinel DB 360 — https://sentineldb360.com
--
--   Çoklu instance'da sürekli izleme, alarm, kalıcılık, dashboard
--   ve AI destekli bulgu için DMC'nin Sentinel DB 360 ürününe bakın.

SELECT
    SYSUTCDATETIME()                                                  AS sample_utc,
    @@SERVERNAME                                                      AS server_name,
    -- CPU pressure (signal_wait_time / wait_time across SOS_SCHEDULER_YIELD)
    (SELECT TOP 1 CAST(100.0 * signal_wait_time_ms
                        / NULLIF(wait_time_ms, 0) AS DECIMAL(5, 2))
     FROM sys.dm_os_wait_stats
     WHERE wait_type = 'SOS_SCHEDULER_YIELD')                         AS cpu_signal_wait_pct,
    -- Buffer pool size
    (SELECT cntr_value / 128
     FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Total Server Memory (KB)')                 AS server_memory_mb,
    (SELECT cntr_value / 128
     FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Target Server Memory (KB)')                AS target_memory_mb,
    -- Page life expectancy — classic memory pressure indicator
    (SELECT cntr_value
     FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Page life expectancy'
       AND object_name LIKE '%:Buffer Manager%')                       AS page_life_expectancy_secs,
    -- Live workload
    (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1)
                                                                       AS user_sessions,
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id > 50)  AS active_requests,
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id <> 0)
                                                                       AS blocked_sessions,
    (SELECT COUNT(*) FROM sys.dm_tran_active_transactions)             AS active_transactions,
    -- Throughput counters (cumulative — diff externally for rate)
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'Batch Requests/sec'
       AND object_name LIKE '%:SQL Statistics%')                      AS batch_requests_cumulative,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = 'SQL Compilations/sec'
       AND object_name LIKE '%:SQL Statistics%')                      AS sql_compilations_cumulative;
