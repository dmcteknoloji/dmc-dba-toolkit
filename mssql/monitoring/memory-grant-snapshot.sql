-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : memory-grant-snapshot                           ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (DMV scan + counter aggregates)        ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-memory-grant-snapshot ║
-- ║  Inspired by   : sys.dm_exec_query_memory_grants and the          ║
-- ║                  RESOURCE_SEMAPHORE wait family — Microsoft       ║
-- ║                  Learn public references.                          ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (memory-grant internals + workspace pressure) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Anlık memory grant baskısını döner: bekleyen / verilmiş grant'lar,
--   istenen vs alınan KB, hash/sort spill'lere yol açan zaman aşımı
--   bekleyenleri. RESOURCE_SEMAPHORE wait'i bu tablonun tam
--   karşılığıdır — ikisini birlikte oku. Yüksek requested_memory_kb
--   ile düşük granted_memory_kb tipik "estimate çok yüksek, gerçek
--   ihtiyaç düşük" parameter sniffing semptomudur.
--
-- Why this exists:
--   When a query requests more memory than its plan can immediately
--   get, it waits on RESOURCE_SEMAPHORE. While waiting, the entire
--   query is paused. This is one of the most common causes of "the
--   query is fine, the system is fine, but it's slow today" — what
--   varies is memory-grant pressure. This snapshot returns the
--   live grant queue, the headline server-level grant counters, and
--   the workspace memory configured cap.

-- ── 1. SERVER-LEVEL HEADLINE ──────────────────────────────────────
SELECT
    SYSUTCDATETIME()                                              AS sample_utc,
    @@SERVERNAME                                                  AS server_name,
    'HEADLINE'                                                    AS section,
    -- Grants outstanding
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants)        AS grants_total_now,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants
     WHERE grant_time IS NOT NULL)                                AS grants_granted_now,
    (SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants
     WHERE grant_time IS NULL)                                    AS grants_waiting_now,
    -- Total memory granted vs requested
    (SELECT SUM(granted_memory_kb) FROM sys.dm_exec_query_memory_grants)
                                                                  AS total_granted_kb_now,
    (SELECT SUM(requested_memory_kb) FROM sys.dm_exec_query_memory_grants)
                                                                  AS total_requested_kb_now,
    (SELECT SUM(used_memory_kb) FROM sys.dm_exec_query_memory_grants)
                                                                  AS total_used_kb_now,
    (SELECT SUM(max_used_memory_kb) FROM sys.dm_exec_query_memory_grants)
                                                                  AS total_max_used_kb_now,
    -- Server-level pressure counters (cumulative)
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = N'Memory Grants Pending'
       AND object_name LIKE N'%:Memory Manager%')                 AS perf_grants_pending,
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = N'Memory Grants Outstanding'
       AND object_name LIKE N'%:Memory Manager%')                 AS perf_grants_outstanding,
    -- Workspace memory ceiling
    (SELECT cntr_value FROM sys.dm_os_performance_counters
     WHERE counter_name = N'Maximum Workspace Memory (KB)'
       AND object_name LIKE N'%:Memory Manager%')                 AS max_workspace_kb;

-- ── 2. GRANT QUEUE DETAIL — who is asking, who is waiting ─────────
SELECT
    'GRANT_DETAIL'                                                AS section,
    g.session_id,
    g.request_id,
    g.scheduler_id,
    -- Wait age
    DATEDIFF(SECOND, g.request_time, SYSUTCDATETIME())            AS request_age_secs,
    g.queue_id                                                    AS resource_semaphore_queue,
    -- Memory amounts
    g.requested_memory_kb,
    g.granted_memory_kb,
    g.required_memory_kb                                          AS minimum_required_kb,
    g.used_memory_kb,
    g.max_used_memory_kb,
    g.ideal_memory_kb,
    -- Grant timing — IS NULL means waiting
    g.grant_time,
    g.timeout_sec                                                 AS grant_timeout_sec,
    -- Plan + session context
    s.host_name,
    s.program_name,
    s.login_name,
    DB_NAME(r.database_id)                                        AS database_name,
    -- Truncated query text
    LEFT(st.text, 200)                                            AS query_preview,
    -- Verdict — flag the patterns that need attention
    CASE
        WHEN g.grant_time IS NULL
             AND DATEDIFF(SECOND, g.request_time, SYSUTCDATETIME()) > 30
            THEN N'🔴 waiting > 30s for memory grant'
        WHEN g.granted_memory_kb > 0
             AND g.granted_memory_kb < g.required_memory_kb
            THEN N'🟠 granted below required — query will spill'
        WHEN g.granted_memory_kb > 0
             AND g.requested_memory_kb > 10 * g.max_used_memory_kb
             AND g.max_used_memory_kb > 0
            THEN N'🟠 requested >10x what was actually used — parameter sniffing suspect'
    END                                                           AS verdict
FROM sys.dm_exec_query_memory_grants    AS g
LEFT JOIN sys.dm_exec_sessions          AS s ON s.session_id = g.session_id
LEFT JOIN sys.dm_exec_requests          AS r ON r.session_id = g.session_id
                                              AND r.request_id = g.request_id
OUTER APPLY sys.dm_exec_sql_text(g.sql_handle) AS st
ORDER BY (g.grant_time IS NULL) DESC,
         g.request_time ASC;
