-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : wait-pressure-snapshot                          ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (one DMV scan, milliseconds)           ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-wait-pressure-snapshot ║
-- ║  Inspired by   : sys.dm_os_wait_stats reference + Paul Randal    ║
-- ║                  benign-wait list (SQLskills public series).      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (output requires deep DMV / internals knowledge)      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: A row per execution with cumulative wait time per category.
--       Schedule every minute, dump to a target table, and you have
--       a wait-stats time series — the most useful long-term view
--       a SQL Server DBA can build. Categorisation is opinionated:
--       Lock / Latch / Buffer IO / IO / CPU / Memory / Network /
--       Compilation / Other. Benign waits are excluded.
--   TR: Çalıştırma başına tek satır, kategori başına kümülatif wait
--       süresi. Dakikada bir çalıştır, hedef tabloya yaz — bir SQL
--       Server DBA'in kurabileceği en değerli uzun vadeli görünüm.
--       Kategoriler: Lock / Latch / Buffer IO / IO / CPU / Memory /
--       Network / Compilation / Other. Zararsız (benign) wait'ler
--       dışarıda bırakılır.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 ingests this snapshot every 60 seconds, charts
--   wait categories side-by-side across every instance, and surfaces
--   "category X is anomalous on instance Y compared to its own
--   weekday-hour baseline" — see https://github.com/dmcteknoloji.

WITH benign AS (
    SELECT wait_type FROM (VALUES
        (N'BROKER_EVENTHANDLER'),(N'BROKER_RECEIVE_WAITFOR'),
        (N'BROKER_TASK_STOP'),(N'BROKER_TO_FLUSH'),
        (N'BROKER_TRANSMITTER'),(N'CHECKPOINT_QUEUE'),(N'CHKPT'),
        (N'CLR_AUTO_EVENT'),(N'CLR_MANUAL_EVENT'),(N'CLR_SEMAPHORE'),
        (N'DBMIRROR_EVENTS_QUEUE'),(N'DBMIRROR_WORKER_QUEUE'),
        (N'DIRTY_PAGE_POLL'),(N'DISPATCHER_QUEUE_SEMAPHORE'),
        (N'EXECSYNC'),(N'FT_IFTS_SCHEDULER_IDLE_WAIT'),
        (N'HADR_FILESTREAM_IOMGR_IOCOMPLETION'),
        (N'HADR_LOGCAPTURE_WAIT'),(N'HADR_NOTIFICATION_DEQUEUE'),
        (N'HADR_TIMER_TASK'),(N'HADR_WORK_QUEUE'),(N'KSOURCE_WAKEUP'),
        (N'LAZYWRITER_SLEEP'),(N'LOGMGR_QUEUE'),
        (N'ONDEMAND_TASK_QUEUE'),(N'PWAIT_ALL_COMPONENTS_INITIALIZED'),
        (N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'),(N'QDS_ASYNC_QUEUE'),
        (N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'),
        (N'REDO_THREAD_PENDING_WORK'),(N'REQUEST_FOR_DEADLOCK_SEARCH'),
        (N'RESOURCE_QUEUE'),(N'SLEEP_BPOOL_FLUSH'),(N'SLEEP_DBSTARTUP'),
        (N'SLEEP_MASTERMDREADY'),(N'SLEEP_SYSTEMTASK'),(N'SLEEP_TASK'),
        (N'SP_SERVER_DIAGNOSTICS_SLEEP'),(N'SQLTRACE_BUFFER_FLUSH'),
        (N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'),(N'SQLTRACE_WAIT_ENTRIES'),
        (N'WAITFOR'),(N'WAIT_XTP_HOST_WAIT'),(N'WAIT_XTP_RECOVERY'),
        (N'XE_DISPATCHER_JOIN'),(N'XE_DISPATCHER_WAIT'),(N'XE_TIMER_EVENT')
    ) AS x(wait_type)
),
categorised AS (
    SELECT
        ws.wait_time_ms,
        ws.signal_wait_time_ms,
        ws.waiting_tasks_count,
        CASE
            WHEN ws.wait_type LIKE 'LCK_M_%'                  THEN N'Lock'
            WHEN ws.wait_type LIKE 'PAGEIOLATCH_%'            THEN N'Buffer IO'
            WHEN ws.wait_type LIKE 'PAGELATCH_%'              THEN N'Buffer Latch'
            WHEN ws.wait_type LIKE 'LATCH_%'                  THEN N'Latch'
            WHEN ws.wait_type LIKE 'IO_%'
                 OR ws.wait_type IN (N'WRITELOG',N'IO_COMPLETION',
                                     N'ASYNC_IO_COMPLETION')   THEN N'IO'
            WHEN ws.wait_type IN (N'SOS_SCHEDULER_YIELD',N'THREADPOOL',
                                  N'CXPACKET',N'CXCONSUMER',
                                  N'CXSYNC_PORT',N'CXSYNC_CONSUMER')
                                                               THEN N'CPU'
            WHEN ws.wait_type LIKE 'RESOURCE_SEMAPHORE%'
                 OR ws.wait_type IN (N'CMEMTHREAD',
                                     N'PAGE_LIFETIME_EXPECTANCY')
                                                               THEN N'Memory'
            WHEN ws.wait_type LIKE 'NETWORK%'
                 OR ws.wait_type IN (N'ASYNC_NETWORK_IO')      THEN N'Network'
            WHEN ws.wait_type LIKE 'SOS_%COMPILE%'
                 OR ws.wait_type IN (N'RESOURCE_SEMAPHORE_QUERY_COMPILE')
                                                               THEN N'Compilation'
            ELSE N'Other'
        END AS category
    FROM sys.dm_os_wait_stats AS ws
    WHERE ws.wait_time_ms > 0
      AND NOT EXISTS (SELECT 1 FROM benign AS b
                      WHERE b.wait_type = ws.wait_type)
)
SELECT
    SYSUTCDATETIME()                                          AS sample_utc,
    @@SERVERNAME                                              AS server_name,
    -- Each category as its own column = ready for a wide time-series table.
    SUM(CASE WHEN category = N'CPU'         THEN wait_time_ms ELSE 0 END)
                                                              AS wait_cpu_ms_cumulative,
    SUM(CASE WHEN category = N'Lock'        THEN wait_time_ms ELSE 0 END)
                                                              AS wait_lock_ms_cumulative,
    SUM(CASE WHEN category = N'Latch'       THEN wait_time_ms ELSE 0 END)
                                                              AS wait_latch_ms_cumulative,
    SUM(CASE WHEN category = N'Buffer IO'   THEN wait_time_ms ELSE 0 END)
                                                              AS wait_buffer_io_ms_cumulative,
    SUM(CASE WHEN category = N'Buffer Latch'THEN wait_time_ms ELSE 0 END)
                                                              AS wait_buffer_latch_ms_cumulative,
    SUM(CASE WHEN category = N'IO'          THEN wait_time_ms ELSE 0 END)
                                                              AS wait_io_ms_cumulative,
    SUM(CASE WHEN category = N'Memory'      THEN wait_time_ms ELSE 0 END)
                                                              AS wait_memory_ms_cumulative,
    SUM(CASE WHEN category = N'Network'     THEN wait_time_ms ELSE 0 END)
                                                              AS wait_network_ms_cumulative,
    SUM(CASE WHEN category = N'Compilation' THEN wait_time_ms ELSE 0 END)
                                                              AS wait_compilation_ms_cumulative,
    SUM(CASE WHEN category = N'Other'       THEN wait_time_ms ELSE 0 END)
                                                              AS wait_other_ms_cumulative,
    SUM(wait_time_ms)                                         AS wait_total_ms_cumulative,
    SUM(signal_wait_time_ms)                                  AS signal_wait_ms_cumulative,
    -- Signal-wait ratio: > 25% of total = look at CPU. Persist this for
    -- a clean "is CPU the bottleneck?" trend chart.
    CAST(100.0 * SUM(signal_wait_time_ms)
         / NULLIF(SUM(wait_time_ms), 0)
         AS DECIMAL(5, 2))                                    AS signal_wait_pct
FROM categorised;
