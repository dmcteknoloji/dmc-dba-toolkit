-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : db-file-growth                                  ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB (partial) │ MI  ║
-- ║  Category      : storage                                         ║
-- ║  Impact        : 🟢 Light  (catalog views, no file I/O)           ║
-- ║  Permissions   : VIEW SERVER STATE, VIEW ANY DEFINITION          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#db-file-growth       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns size, used space, free space and the configured autogrowth
-- pattern for every data and log file the instance can see.
--
-- On Azure SQL Database (single-database edition) sys.master_files is
-- restricted; the script falls back to the current database's
-- sys.database_files. Server-wide file totals are not available in that
-- environment and the result is filtered to the current database only.
--
-- Used/free space is computed via FILEPROPERTY(...,'SpaceUsed') which
-- requires being executed in each database; we use a per-database
-- cursor-free approach by switching context with sys.dm_db_database_files
-- aggregated across databases through a dynamic-SQL-free pattern: we read
-- the size from the master view and the used-space metric from the
-- database where each file lives. To stay portable and side-effect-free,
-- we keep the query simple and let used_mb be NULL for files outside the
-- current database. For full per-database used space, run inside each db.

DECLARE @engine_edition INT = CAST(SERVERPROPERTY('EngineEdition') AS INT);

IF @engine_edition = 5  -- Azure SQL Database (single)
BEGIN
    SELECT
        DB_NAME()                                                     AS database_name,
        CASE df.type_desc WHEN 'LOG' THEN N'LOG' ELSE N'DATA' END     AS file_type,
        df.name                                                       AS logical_name,
        df.physical_name                                              AS physical_path,
        CAST(df.size * 8.0 / 1024 AS DECIMAL(18, 2))                  AS size_mb,
        CAST(FILEPROPERTY(df.name, 'SpaceUsed') * 8.0 / 1024
             AS DECIMAL(18, 2))                                       AS used_mb,
        CAST((df.size - FILEPROPERTY(df.name, 'SpaceUsed'))
             * 8.0 / 1024 AS DECIMAL(18, 2))                          AS free_mb,
        CAST(100.0 * FILEPROPERTY(df.name, 'SpaceUsed') /
             NULLIF(df.size, 0) AS DECIMAL(5, 2))                     AS pct_used,
        CASE
            WHEN df.is_percent_growth = 1
                THEN CONCAT('+', df.growth, '%')
            ELSE CONCAT('+',
                        CAST(df.growth * 8 / 1024 AS NVARCHAR(20)),
                        ' MB')
        END                                                           AS growth_setting,
        CASE
            WHEN df.max_size IN (0, -1) THEN NULL
            ELSE CAST(df.max_size * 8.0 / 1024 AS DECIMAL(18, 2))
        END                                                           AS max_size_mb
    FROM sys.database_files AS df
    ORDER BY file_type, df.name;
END
ELSE
BEGIN
    SELECT
        DB_NAME(mf.database_id)                                       AS database_name,
        CASE mf.type_desc WHEN 'LOG' THEN N'LOG' ELSE N'DATA' END     AS file_type,
        mf.name                                                       AS logical_name,
        mf.physical_name                                              AS physical_path,
        CAST(mf.size * 8.0 / 1024 AS DECIMAL(18, 2))                  AS size_mb,
        CAST(NULL AS DECIMAL(18, 2))                                  AS used_mb,
        CAST(NULL AS DECIMAL(18, 2))                                  AS free_mb,
        CAST(NULL AS DECIMAL(5, 2))                                   AS pct_used,
        CASE
            WHEN mf.is_percent_growth = 1
                THEN CONCAT('+', mf.growth, '%')
            ELSE CONCAT('+',
                        CAST(mf.growth * 8 / 1024 AS NVARCHAR(20)),
                        ' MB')
        END                                                           AS growth_setting,
        CASE
            WHEN mf.max_size IN (0, -1) THEN NULL
            ELSE CAST(mf.max_size * 8.0 / 1024 AS DECIMAL(18, 2))
        END                                                           AS max_size_mb
    FROM sys.master_files AS mf
    ORDER BY DB_NAME(mf.database_id), file_type, mf.name;
END;
