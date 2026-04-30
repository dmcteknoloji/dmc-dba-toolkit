-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : top-cpu-queries                                 ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (read-only DMV scan, no recompiles)    ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#top-cpu-queries      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-04-15                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the top CPU consumers currently in the plan cache, ranked by
-- cumulative worker time. Groups by query_hash so plan recompiles don't
-- split a single logical query into multiple rows.
--
-- The plan cache is a moving target: queries that fell out of cache (e.g.
-- after a memory pressure event, RECOMPILE hint, or DBCC FREEPROCCACHE)
-- are not represented. Treat this as "what's expensive *now*", not "what
-- was ever expensive".

DECLARE @top_n INT = 25;

;WITH ranked AS (
    SELECT
        qs.query_hash,
        SUM(qs.execution_count)         AS executions,
        SUM(qs.total_worker_time)       AS total_cpu_us,
        SUM(qs.total_elapsed_time)      AS total_elapsed_us,
        SUM(qs.total_logical_reads)     AS total_logical_reads,
        MAX(qs.last_execution_time)     AS last_execution_time,
        MIN(qs.sql_handle)              AS any_sql_handle,
        MIN(qs.statement_start_offset)  AS any_start_offset,
        MIN(qs.statement_end_offset)    AS any_end_offset,
        MIN(qs.plan_handle)             AS any_plan_handle
    FROM sys.dm_exec_query_stats AS qs
    GROUP BY qs.query_hash
)
SELECT TOP (@top_n)
    ROW_NUMBER() OVER (ORDER BY r.total_cpu_us DESC)            AS [rank],
    r.query_hash,
    r.executions,
    r.total_cpu_us / 1000                                       AS total_cpu_ms,
    CAST(r.total_cpu_us / 1000.0 / NULLIF(r.executions, 0)
         AS DECIMAL(18, 2))                                     AS avg_cpu_ms,
    r.total_elapsed_us / 1000                                   AS total_elapsed_ms,
    CAST(r.total_elapsed_us / 1000.0 / NULLIF(r.executions, 0)
         AS DECIMAL(18, 2))                                     AS avg_elapsed_ms,
    r.total_logical_reads,
    r.total_logical_reads / NULLIF(r.executions, 0)             AS avg_logical_reads,
    r.last_execution_time,
    DB_NAME(CAST(pa.value AS INT))                              AS database_name,
    SUBSTRING(
        st.text,
        (r.any_start_offset / 2) + 1,
        ((CASE r.any_end_offset
              WHEN -1 THEN DATALENGTH(st.text)
              ELSE r.any_end_offset
          END - r.any_start_offset) / 2) + 1
    )                                                           AS query_text
FROM ranked AS r
CROSS APPLY sys.dm_exec_sql_text(r.any_sql_handle)              AS st
OUTER APPLY sys.dm_exec_plan_attributes(r.any_plan_handle)      AS pa
WHERE pa.attribute = N'dbid'
ORDER BY r.total_cpu_us DESC;
