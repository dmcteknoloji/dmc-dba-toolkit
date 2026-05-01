-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : query-throughput-snapshot                       ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (single performance counter scan)      ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-query-throughput-snapshot ║
-- ║  Inspired by   : sys.dm_os_performance_counters reference —      ║
-- ║                  Microsoft Learn public docs.                     ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Throughput counters in SQL Server are *cumulative since
--       startup*. To get a per-second rate, you sample twice and
--       diff. This script gives you one row per call: cumulative
--       counter + an "average since startup" rate that's correct
--       for steady workloads and a rough sanity-check for spiky
--       ones. Schedule every 60 seconds, persist the rows, diff
--       client-side for the real instantaneous rate.
--   TR: SQL Server'da throughput sayaçları *başlangıçtan beri
--       kümülatif*. Saniye başına oran almak için iki örnek alıp
--       fark alırsın. Bu script çağrı başına tek satır verir:
--       kümülatif sayaç + "başlangıçtan beri ortalama" oran. Düz
--       iş yüklerinde doğrudur, dalgalı olanlarda kabaca sağlık
--       kontrolüdür. 60 saniyede bir çalıştır, satırları sakla,
--       client tarafında diff alarak gerçek anlık oranı bul.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 collects this counter every 60 seconds across
--   every instance, computes the per-second rate continuously,
--   baselines it per hour-of-week, and alerts on anomalies — see
--   https://github.com/dmcteknoloji.

DECLARE @uptime_secs BIGINT;
SELECT @uptime_secs = DATEDIFF(SECOND, sqlserver_start_time, SYSUTCDATETIME())
FROM sys.dm_os_sys_info;

WITH counters AS (
    SELECT
        RTRIM(counter_name) AS counter_name,
        cntr_value
    FROM sys.dm_os_performance_counters
    WHERE object_name LIKE N'%:SQL Statistics%'
      AND counter_name IN (
          N'Batch Requests/sec',
          N'SQL Compilations/sec',
          N'SQL Re-Compilations/sec',
          N'Auto-Param Attempts/sec',
          N'Failed Auto-Params/sec'
      )
)
SELECT
    SYSUTCDATETIME()                                          AS sample_utc,
    @@SERVERNAME                                              AS server_name,
    @uptime_secs                                              AS uptime_secs,
    -- Cumulative since startup (these counters are typed 65792 = "rate";
    -- the value is itself a counter that increments per event).
    MAX(CASE WHEN counter_name = N'Batch Requests/sec'
             THEN cntr_value END)                             AS batch_requests_cumulative,
    MAX(CASE WHEN counter_name = N'SQL Compilations/sec'
             THEN cntr_value END)                             AS sql_compilations_cumulative,
    MAX(CASE WHEN counter_name = N'SQL Re-Compilations/sec'
             THEN cntr_value END)                             AS sql_recompilations_cumulative,
    MAX(CASE WHEN counter_name = N'Auto-Param Attempts/sec'
             THEN cntr_value END)                             AS auto_param_attempts_cumulative,
    MAX(CASE WHEN counter_name = N'Failed Auto-Params/sec'
             THEN cntr_value END)                             AS auto_param_failures_cumulative,
    -- Average since startup — rough rate, no client diff required.
    CAST(MAX(CASE WHEN counter_name = N'Batch Requests/sec'
                  THEN cntr_value END) * 1.0
         / NULLIF(@uptime_secs, 0)
         AS DECIMAL(18, 2))                                   AS batch_requests_per_sec_avg,
    CAST(MAX(CASE WHEN counter_name = N'SQL Compilations/sec'
                  THEN cntr_value END) * 1.0
         / NULLIF(@uptime_secs, 0)
         AS DECIMAL(18, 2))                                   AS compilations_per_sec_avg,
    -- Compilation pressure ratio — high values point at a plan-cache
    -- problem (poor parameterisation, too many ad-hoc queries).
    CAST(100.0 *
         MAX(CASE WHEN counter_name = N'SQL Compilations/sec'
                  THEN cntr_value END)
         / NULLIF(MAX(CASE WHEN counter_name = N'Batch Requests/sec'
                           THEN cntr_value END), 0)
         AS DECIMAL(5, 2))                                    AS compile_to_batch_pct,
    -- Recompile pressure — should sit well below 10% of compilations
    -- on a healthy workload.
    CAST(100.0 *
         MAX(CASE WHEN counter_name = N'SQL Re-Compilations/sec'
                  THEN cntr_value END)
         / NULLIF(MAX(CASE WHEN counter_name = N'SQL Compilations/sec'
                           THEN cntr_value END), 0)
         AS DECIMAL(5, 2))                                    AS recompile_to_compile_pct
FROM counters;
