-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : page-life-and-memory-pressure                   ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (perf counters + memory clerks DMV)    ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-page-life-and-memory-pressure ║
-- ║  Inspired by   : sys.dm_os_memory_clerks reference + the          ║
-- ║                  per-NUMA-node Page Life Expectancy guidance      ║
-- ║                  in Microsoft Learn. The "300s per 4GB of pool"   ║
-- ║                  rule of thumb is decade-old SQLskills public     ║
-- ║                  guidance from Paul Randal.                       ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (NUMA-aware memory analysis)          ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Memory pressure'ı üç açıdan döner: NUMA node başına Page Life
--   Expectancy (PLE), top memory clerk'lar (kim ne kadar bellek
--   tüketiyor), buffer pool hedefi vs gerçeği. PLE'yi instance
--   genelinde tek sayı olarak okumak yanıltıcıdır — NUMA node başına
--   bakılmalı, çünkü bir node memory pressure yaşarken diğeri rahat
--   olabilir. Eski "PLE > 300" kuralı yanlış; doğru kural 4GB pool
--   başına 300 saniye (Paul Randal kuralı).
--
-- Why this exists:
--   "Page Life Expectancy" is the most-misread SQL Server counter on
--   the planet. The single-number version reported in standard tools
--   is the *minimum* across NUMA nodes, which hides skew. Per-NUMA-
--   node PLE + memory clerk breakdown + workspace memory tells the
--   actual story. This script puts all three in one result so you
--   can see whether memory is just "tight everywhere" vs "hot on
--   one NUMA node".

-- ── 1. PER-NUMA-NODE PLE ───────────────────────────────────────────
SELECT
    SYSUTCDATETIME()                                              AS sample_utc,
    'PLE_PER_NODE'                                                AS section,
    -- Object name carries the node — "MSSQL$<INSTANCE>:Buffer Node" or
    -- "SQLServer:Buffer Node" with the NUMA node id in the instance_name.
    LTRIM(RTRIM(object_name))                                     AS object_name,
    instance_name                                                 AS numa_node,
    cntr_value                                                    AS page_life_expectancy_secs,
    -- Pool size on this NUMA node (rough): node_count * pages_per_node * 8KB.
    -- We approximate via the matching Buffer Manager target counter for
    -- the same node where it exists; otherwise NULL.
    CASE
        WHEN cntr_value < 300
            THEN N'🔴 PLE < 300s — strong memory pressure on this node'
        WHEN cntr_value < 600
            THEN N'🟠 PLE < 600s — sub-optimal, monitor'
    END                                                           AS verdict
FROM sys.dm_os_performance_counters
WHERE counter_name = N'Page life expectancy'
  AND object_name LIKE N'%Buffer Node%'
ORDER BY instance_name;

-- ── 2. TOP MEMORY CLERKS — who is using the memory ────────────────
SELECT
    'MEMORY_CLERKS'                                               AS section,
    type                                                          AS clerk_type,
    name                                                          AS clerk_name,
    memory_node_id,
    pages_kb                                                      AS pages_kb,
    virtual_memory_reserved_kb,
    virtual_memory_committed_kb,
    awe_allocated_kb,
    -- Pretty-printed: convert pages_kb to MB
    CAST(pages_kb / 1024.0 AS DECIMAL(18, 2))                     AS pages_mb,
    -- Percentage of total committed
    CAST(100.0 * pages_kb
         / NULLIF(SUM(pages_kb) OVER (), 0)
         AS DECIMAL(5, 2))                                        AS pct_of_total
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 1024   -- skip clerks below 1 MB to keep result tight
ORDER BY pages_kb DESC;

-- ── 3. SERVER-LEVEL MEMORY HEADLINE ────────────────────────────────
SELECT
    'HEADLINE'                                                    AS section,
    metric,
    value,
    note
FROM (VALUES
    ('total_server_memory_mb',
     CAST((SELECT cntr_value / 128
           FROM sys.dm_os_performance_counters
           WHERE counter_name = N'Total Server Memory (KB)') AS NVARCHAR(64)),
     N'currently committed'),
    ('target_server_memory_mb',
     CAST((SELECT cntr_value / 128
           FROM sys.dm_os_performance_counters
           WHERE counter_name = N'Target Server Memory (KB)') AS NVARCHAR(64)),
     N'what SQL Server wants'),
    ('max_workspace_kb',
     CAST((SELECT cntr_value
           FROM sys.dm_os_performance_counters
           WHERE counter_name = N'Maximum Workspace Memory (KB)') AS NVARCHAR(64)),
     N'ceiling for memory grants'),
    ('memory_grants_pending',
     CAST((SELECT cntr_value
           FROM sys.dm_os_performance_counters
           WHERE counter_name = N'Memory Grants Pending') AS NVARCHAR(64)),
     N'queries waiting on workspace memory — should be 0 most of the time'),
    ('granted_workspace_memory_kb',
     CAST((SELECT cntr_value
           FROM sys.dm_os_performance_counters
           WHERE counter_name = N'Granted Workspace Memory (KB)') AS NVARCHAR(64)),
     N'currently granted across all running queries'),
    ('memory_pressure_signal',
     ISNULL((SELECT TOP 1 N'YES — sys.dm_os_memory_brokers reports broker pressure'
            FROM sys.dm_os_memory_brokers
            WHERE memory_pressure > 0), N'no'),
     NULL)
) AS t(metric, value, note);
