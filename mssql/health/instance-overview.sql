-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : instance-overview                               ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB (partial) │ MI  ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (server properties + a few DMVs)       ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#instance-overview    ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-09-28                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- A one-screen summary of this SQL Server instance: who it is, what it's
-- running on, how long it has been up, what its workload looks like, and
-- whether its backups are recent.
--
-- The result is a single union-shaped table with a `section` discriminator
-- so it ships clean into a dashboard or a CSV. Some rows are omitted on
-- Azure SQL DB where the underlying DMV is unavailable (machine name,
-- process id, OS-level memory).

DECLARE @engine_edition INT = CAST(SERVERPROPERTY('EngineEdition') AS INT);
DECLARE @is_azure_db BIT = CASE WHEN @engine_edition = 5 THEN 1 ELSE 0 END;

DECLARE @uptime_min INT;
SELECT @uptime_min = DATEDIFF(MINUTE, sqlserver_start_time, SYSUTCDATETIME())
FROM sys.dm_os_sys_info;

DECLARE @uptime_text NVARCHAR(64) = CONCAT(
    @uptime_min / 1440, N'd ',
    RIGHT(CONCAT(N'00', (@uptime_min % 1440) / 60), 2), N'h ',
    RIGHT(CONCAT(N'00', @uptime_min % 60), 2), N'm'
);

;WITH overview AS (
    -- ── IDENTITY ─────────────────────────────────────────────────────
    SELECT N'IDENTITY' AS section, N'product_version'   AS metric,
           CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(256)) AS value,
           CAST(NULL AS NVARCHAR(256)) AS note, 1 AS sort_order
    UNION ALL
    SELECT N'IDENTITY', N'product_level',
           CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(256)), NULL, 2
    UNION ALL
    SELECT N'IDENTITY', N'edition',
           CAST(SERVERPROPERTY('Edition') AS NVARCHAR(256)), NULL, 3
    UNION ALL
    SELECT N'IDENTITY', N'engine_edition',
           CAST(@engine_edition AS NVARCHAR(256)),
           CASE @engine_edition
               WHEN 1 THEN N'Personal/Desktop'
               WHEN 2 THEN N'Standard'
               WHEN 3 THEN N'Enterprise'
               WHEN 4 THEN N'Express'
               WHEN 5 THEN N'Azure SQL Database'
               WHEN 6 THEN N'Azure Synapse Analytics'
               WHEN 8 THEN N'Azure SQL Managed Instance'
               WHEN 9 THEN N'Azure SQL Edge'
               WHEN 11 THEN N'Azure SQL Database (Hyperscale)'
               ELSE N'unknown'
           END, 4
    UNION ALL
    SELECT N'IDENTITY', N'collation',
           CAST(SERVERPROPERTY('Collation') AS NVARCHAR(256)), NULL, 5
    UNION ALL
    SELECT N'IDENTITY', N'instance_name',
           ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(256)),
                  N'<default>'), NULL, 6
    UNION ALL
    SELECT N'IDENTITY', N'machine_name',
           ISNULL(CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(256)),
                  N'<n/a on this edition>'),
           CASE WHEN @is_azure_db = 1
                THEN N'unavailable on Azure SQL DB' END, 7

    -- ── UPTIME ───────────────────────────────────────────────────────
    UNION ALL
    SELECT N'UPTIME', N'sqlserver_start_time',
           CAST(CONVERT(NVARCHAR(30), sqlserver_start_time, 120) AS NVARCHAR(256)),
           NULL, 1
    FROM sys.dm_os_sys_info
    UNION ALL
    SELECT N'UPTIME', N'uptime',
           @uptime_text,
           CASE WHEN @uptime_min < 60 THEN N'instance restarted within the last hour' END,
           2
)
SELECT section, metric, value, note
FROM overview
ORDER BY
    CASE section
        WHEN N'IDENTITY' THEN 1
        WHEN N'RESOURCES' THEN 2
        WHEN N'UPTIME' THEN 3
        WHEN N'WORKLOAD' THEN 4
        WHEN N'BACKUPS' THEN 5
        ELSE 99
    END,
    sort_order;

-- ── RESOURCES (skipped on Azure SQL DB single) ─────────────────────────
IF @is_azure_db = 0
BEGIN
    SELECT
        N'RESOURCES'                                                  AS section,
        m.metric,
        m.value,
        m.note
    FROM (
        SELECT N'cpu_count' AS metric,
               CAST(cpu_count AS NVARCHAR(256)) AS value,
               N'logical CPUs visible to SQL Server' AS note,
               1 AS sort_order
        FROM sys.dm_os_sys_info
        UNION ALL
        SELECT N'physical_memory_gb',
               CAST(CAST(physical_memory_kb / 1048576.0 AS DECIMAL(10, 2))
                    AS NVARCHAR(256)),
               N'committed memory on the host',
               2
        FROM sys.dm_os_sys_info
        UNION ALL
        SELECT N'max_server_memory_mb',
               CAST(c.value_in_use AS NVARCHAR(256)),
               N'sp_configure ''max server memory''',
               3
        FROM sys.configurations AS c
        WHERE c.name = N'max server memory (MB)'
    ) AS m
    ORDER BY m.sort_order;
END;

-- ── WORKLOAD ───────────────────────────────────────────────────────────
SELECT
    N'WORKLOAD'                                                       AS section,
    m.metric,
    m.value,
    m.note
FROM (
    SELECT N'database_count' AS metric,
           CAST(COUNT(*) AS NVARCHAR(256)) AS value,
           NULL AS note, 1 AS sort_order
    FROM sys.databases
    WHERE database_id > 4
    UNION ALL
    SELECT N'sessions_total',
           CAST(COUNT(*) AS NVARCHAR(256)),
           NULL, 2
    FROM sys.dm_exec_sessions
    WHERE is_user_process = 1
    UNION ALL
    SELECT N'requests_running',
           CAST(COUNT(*) AS NVARCHAR(256)),
           NULL, 3
    FROM sys.dm_exec_requests
    WHERE session_id > 50
    UNION ALL
    SELECT N'sessions_blocked',
           CAST(COUNT(*) AS NVARCHAR(256)),
           CASE WHEN COUNT(*) > 0 THEN N'see blocking-chain.sql' END,
           4
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
) AS m
ORDER BY m.sort_order;

-- ── BACKUPS (skipped on Azure SQL DB single) ───────────────────────────
IF @is_azure_db = 0
BEGIN
    SELECT
        N'BACKUPS'                                                    AS section,
        d.name                                                        AS metric,
        ISNULL(CONVERT(NVARCHAR(30),
                       MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END),
                       120),
               N'<no full backup recorded>')                          AS value,
        CASE
            WHEN MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) IS NULL
                THEN N'no full backup ever — investigate'
            WHEN DATEDIFF(DAY,
                          MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END),
                          SYSUTCDATETIME()) > 7
                THEN N'last full backup is more than 7 days old'
        END                                                           AS note
    FROM sys.databases AS d
    LEFT JOIN msdb.dbo.backupset AS bs
        ON bs.database_name = d.name
    WHERE d.database_id > 4
      AND d.state_desc = N'ONLINE'
    GROUP BY d.name
    ORDER BY d.name;
END;
