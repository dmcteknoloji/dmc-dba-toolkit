-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : wait-stats-summary                              ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (single DMV scan)                      ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#wait-stats-summary   ║
-- ║  Inspired by   : Paul Randal (SQLskills) — public Wait Statistics║
-- ║                  blog series. Technique credited; code original. ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-05-22                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Aggregates sys.dm_os_wait_stats into meaningful categories with the
-- usual benign waits filtered out.
--
-- The "benign waits" list below is widely shared in the community via
-- Paul Randal's public SQLskills blog series. We re-implemented it here
-- and keep it current against publicly documented wait types from
-- Microsoft Learn (sys.dm_os_wait_stats reference). No private content.
--
-- Wait stats are cumulative since instance startup or last
-- DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR). For a snapshot of *current*
-- pressure, capture twice with a delay and diff. This script gives you
-- the "all time" view, which is the right starting point.

WITH benign AS (
    SELECT wait_type
    FROM (VALUES
        (N'BROKER_EVENTHANDLER'), (N'BROKER_RECEIVE_WAITFOR'),
        (N'BROKER_TASK_STOP'), (N'BROKER_TO_FLUSH'),
        (N'BROKER_TRANSMITTER'), (N'CHECKPOINT_QUEUE'),
        (N'CHKPT'), (N'CLR_AUTO_EVENT'), (N'CLR_MANUAL_EVENT'),
        (N'CLR_SEMAPHORE'), (N'DBMIRROR_DBM_EVENT'),
        (N'DBMIRROR_EVENTS_QUEUE'), (N'DBMIRROR_WORKER_QUEUE'),
        (N'DBMIRRORING_CMD'), (N'DIRTY_PAGE_POLL'),
        (N'DISPATCHER_QUEUE_SEMAPHORE'), (N'EXECSYNC'),
        (N'FSAGENT'), (N'FT_IFTS_SCHEDULER_IDLE_WAIT'),
        (N'FT_IFTSHC_MUTEX'), (N'HADR_CLUSAPI_CALL'),
        (N'HADR_FILESTREAM_IOMGR_IOCOMPLETION'),
        (N'HADR_LOGCAPTURE_WAIT'), (N'HADR_NOTIFICATION_DEQUEUE'),
        (N'HADR_TIMER_TASK'), (N'HADR_WORK_QUEUE'),
        (N'KSOURCE_WAKEUP'), (N'LAZYWRITER_SLEEP'), (N'LOGMGR_QUEUE'),
        (N'MEMORY_ALLOCATION_EXT'), (N'ONDEMAND_TASK_QUEUE'),
        (N'PARALLEL_REDO_DRAIN_WORKER'),
        (N'PARALLEL_REDO_LOG_CACHE'), (N'PARALLEL_REDO_TRAN_LIST'),
        (N'PARALLEL_REDO_WORKER_SYNC'),
        (N'PARALLEL_REDO_WORKER_WAIT_WORK'),
        (N'PREEMPTIVE_HADR_LEASE_MECHANISM'),
        (N'PREEMPTIVE_SP_SERVER_DIAGNOSTICS'),
        (N'PREEMPTIVE_OS_LIBRARYOPS'),
        (N'PREEMPTIVE_OS_COMOPS'), (N'PREEMPTIVE_OS_CRYPTOPS'),
        (N'PREEMPTIVE_OS_PIPEOPS'), (N'PREEMPTIVE_OS_AUTHENTICATIONOPS'),
        (N'PREEMPTIVE_OS_GENERICOPS'), (N'PREEMPTIVE_OS_VERIFYTRUST'),
        (N'PREEMPTIVE_OS_FILEOPS'), (N'PREEMPTIVE_OS_DEVICEOPS'),
        (N'PREEMPTIVE_OS_QUERYREGISTRY'),
        (N'PREEMPTIVE_OS_WRITEFILEGATHER'),
        (N'PREEMPTIVE_XE_GETTARGETSTATE'),
        (N'PREEMPTIVE_XE_DISPATCHER'),
        (N'PWAIT_ALL_COMPONENTS_INITIALIZED'),
        (N'PWAIT_DIRECTLOGCONSUMER_GETNEXT'),
        (N'PWAIT_EXTENSIBILITY_CLEANUP_TASK'),
        (N'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'),
        (N'QDS_ASYNC_QUEUE'), (N'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'),
        (N'QDS_SHUTDOWN_QUEUE'), (N'REDO_THREAD_PENDING_WORK'),
        (N'REQUEST_FOR_DEADLOCK_SEARCH'), (N'RESOURCE_QUEUE'),
        (N'SERVER_IDLE_CHECK'), (N'SLEEP_BPOOL_FLUSH'),
        (N'SLEEP_DBSTARTUP'), (N'SLEEP_DCOMSTARTUP'),
        (N'SLEEP_MASTERDBREADY'), (N'SLEEP_MASTERMDREADY'),
        (N'SLEEP_MASTERUPGRADED'), (N'SLEEP_MSDBSTARTUP'),
        (N'SLEEP_SYSTEMTASK'), (N'SLEEP_TASK'), (N'SLEEP_TEMPDBSTARTUP'),
        (N'SNI_HTTP_ACCEPT'), (N'SP_SERVER_DIAGNOSTICS_SLEEP'),
        (N'SQLTRACE_BUFFER_FLUSH'), (N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'),
        (N'SQLTRACE_WAIT_ENTRIES'), (N'WAIT_FOR_RESULTS'),
        (N'WAITFOR'), (N'WAITFOR_TASKSHUTDOWN'), (N'WAIT_XTP_HOST_WAIT'),
        (N'WAIT_XTP_OFFLINE_CKPT_NEW_LOG'), (N'WAIT_XTP_CKPT_CLOSE'),
        (N'WAIT_XTP_RECOVERY'), (N'XE_DISPATCHER_JOIN'),
        (N'XE_DISPATCHER_WAIT'), (N'XE_TIMER_EVENT')
    ) AS x(wait_type)
),
categorised AS (
    SELECT
        ws.wait_type,
        ws.wait_time_ms,
        ws.signal_wait_time_ms,
        ws.waiting_tasks_count,
        CASE
            WHEN ws.wait_type LIKE 'LCK_M_%'                 THEN N'Lock'
            WHEN ws.wait_type LIKE 'LATCH_%'                 THEN N'Latch'
            WHEN ws.wait_type LIKE 'PAGELATCH_%'             THEN N'Buffer Latch'
            WHEN ws.wait_type LIKE 'PAGEIOLATCH_%'           THEN N'Buffer IO'
            WHEN ws.wait_type LIKE 'IO_%' OR
                 ws.wait_type IN (N'WRITELOG', N'ASYNC_IO_COMPLETION',
                                  N'IO_COMPLETION')          THEN N'IO'
            WHEN ws.wait_type IN (N'SOS_SCHEDULER_YIELD', N'THREADPOOL',
                                  N'CXPACKET', N'CXCONSUMER',
                                  N'CXSYNC_PORT', N'CXSYNC_CONSUMER')
                                                              THEN N'CPU'
            WHEN ws.wait_type LIKE 'RESOURCE_SEMAPHORE%' OR
                 ws.wait_type IN (N'CMEMTHREAD',
                                  N'PAGE_LIFETIME_EXPECTANCY')
                                                              THEN N'Memory'
            WHEN ws.wait_type LIKE 'NETWORK%' OR
                 ws.wait_type IN (N'ASYNC_NETWORK_IO',
                                  N'EXTERNAL_SCRIPT_NETWORK_IOF')
                                                              THEN N'Network'
            WHEN ws.wait_type LIKE 'SOS_%COMPILE%' OR
                 ws.wait_type IN (N'RESOURCE_SEMAPHORE_QUERY_COMPILE')
                                                              THEN N'Compilation'
            ELSE N'Other'
        END AS category
    FROM sys.dm_os_wait_stats AS ws
    WHERE ws.wait_time_ms > 0
      AND NOT EXISTS (SELECT 1 FROM benign AS b
                      WHERE b.wait_type = ws.wait_type)
)
SELECT
    c.category,
    c.wait_type,
    CAST(c.wait_time_ms / 1000.0 AS DECIMAL(18, 2))             AS wait_time_sec,
    CAST(100.0 * c.wait_time_ms /
         NULLIF(SUM(c.wait_time_ms) OVER (), 0)
         AS DECIMAL(5, 2))                                      AS pct_of_total,
    CAST(c.signal_wait_time_ms / 1000.0 AS DECIMAL(18, 2))      AS signal_wait_sec,
    CAST(100.0 * c.signal_wait_time_ms /
         NULLIF(c.wait_time_ms, 0)
         AS DECIMAL(5, 2))                                      AS signal_pct,
    c.waiting_tasks_count                                        AS waiting_tasks,
    CAST(c.wait_time_ms * 1.0 /
         NULLIF(c.waiting_tasks_count, 0)
         AS DECIMAL(18, 2))                                     AS avg_wait_ms
FROM categorised AS c
ORDER BY c.wait_time_ms DESC;
