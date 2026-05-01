-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : tempdb-pressure-snapshot                        ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (catalog + space DMVs)                 ║
-- ║  Permissions   : VIEW SERVER STATE, VIEW DATABASE STATE          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-tempdb-pressure-snapshot ║
-- ║  Inspired by   : sys.dm_db_file_space_usage and the version-store║
-- ║                  DMV family — Microsoft Learn public docs.        ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: TempDB is the silent killer. It absorbs sort overflows,
--       hash spills, version-store growth, internal worktables and
--       user temp objects — all sharing one pool. When pressure
--       builds, you see "tempdb is full" or page-allocation
--       contention (PAGELATCH_UP on PFS/GAM/SGAM pages). Trended,
--       this script turns that "what just happened" into "we knew
--       about it 20 minutes ago".
--   TR: TempDB sessiz katildir. Sort overflow'larını, hash spill'leri,
--       version-store büyümesini, dahili worktable'ları ve kullanıcı
--       temp objelerini emer — hepsi tek havuzu paylaşır. Baskı
--       arttığında "tempdb is full" veya page allocation contention
--       (PFS/GAM/SGAM sayfalarında PAGELATCH_UP) görürsün. Trend
--       alındığında bu script "şimdi ne oldu"yu "20 dakika önce
--       biliyorduk"a dönüştürür.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 charts the four tempdb pressure dimensions —
--   user objects, internal objects, version store, and free space —
--   side-by-side, with allocation contention overlaid. See
--   https://github.com/dmcteknoloji.

DECLARE @engine_edition INT = CAST(SERVERPROPERTY('EngineEdition') AS INT);

IF @engine_edition = 5
BEGIN
    SELECT N'INFO' AS section,
           N'tempdb pressure not exposed on Azure SQL Database (single)' AS message;
    RETURN;
END;

WITH file_usage AS (
    SELECT
        SUM(unallocated_extent_page_count)            AS unallocated_pages,
        SUM(user_object_reserved_page_count)          AS user_object_pages,
        SUM(internal_object_reserved_page_count)      AS internal_object_pages,
        SUM(version_store_reserved_page_count)        AS version_store_pages,
        SUM(mixed_extent_page_count)                  AS mixed_pages
    FROM sys.dm_db_file_space_usage
    WHERE database_id = DB_ID(N'tempdb')
),
file_size AS (
    SELECT
        SUM(size) * 8 AS total_kb,        -- size is in 8KB pages
        COUNT(*)      AS file_count
    FROM tempdb.sys.database_files
    WHERE type_desc = N'ROWS'
),
allocation_contention AS (
    -- PFS/GAM/SGAM page latch waits indicate allocation contention.
    SELECT
        SUM(CASE WHEN wait_type LIKE 'PAGELATCH_%'
                 AND resource_description LIKE '2:%:1'    -- PFS pages on tempdb
                 THEN wait_time ELSE 0 END)                 AS pfs_wait_ms_now,
        SUM(CASE WHEN wait_type LIKE 'PAGELATCH_%'
                 AND resource_description LIKE '2:%:2'    -- GAM
                 THEN wait_time ELSE 0 END)                 AS gam_wait_ms_now,
        SUM(CASE WHEN wait_type LIKE 'PAGELATCH_%'
                 AND resource_description LIKE '2:%:3'    -- SGAM
                 THEN wait_time ELSE 0 END)                 AS sgam_wait_ms_now,
        COUNT(CASE WHEN wait_type LIKE 'PAGELATCH_%'
                   AND resource_description LIKE '2:%'
                   THEN 1 END)                              AS pages_in_alloc_wait
    FROM sys.dm_exec_requests
    WHERE database_id = DB_ID(N'tempdb')
)
SELECT
    SYSUTCDATETIME()                                       AS sample_utc,
    @@SERVERNAME                                           AS server_name,
    -- Sizes in MB (page count * 8 / 1024)
    fs.file_count                                          AS tempdb_file_count,
    CAST(fs.total_kb / 1024.0 AS DECIMAL(18, 2))           AS total_size_mb,
    CAST(fu.unallocated_pages * 8 / 1024.0 AS DECIMAL(18, 2))
                                                           AS free_mb,
    CAST(fu.user_object_pages * 8 / 1024.0 AS DECIMAL(18, 2))
                                                           AS user_objects_mb,
    CAST(fu.internal_object_pages * 8 / 1024.0 AS DECIMAL(18, 2))
                                                           AS internal_objects_mb,
    CAST(fu.version_store_pages * 8 / 1024.0 AS DECIMAL(18, 2))
                                                           AS version_store_mb,
    CAST(fu.mixed_pages * 8 / 1024.0 AS DECIMAL(18, 2))
                                                           AS mixed_pages_mb,
    -- Pressure ratio: used / total
    CAST(100.0 *
         (fu.user_object_pages + fu.internal_object_pages + fu.version_store_pages)
         * 8 / NULLIF(fs.total_kb, 0)
         AS DECIMAL(5, 2))                                 AS pct_used,
    -- Allocation contention indicators
    ac.pages_in_alloc_wait                                 AS pages_in_alloc_wait_now,
    ac.pfs_wait_ms_now                                     AS pfs_wait_ms_now,
    ac.gam_wait_ms_now                                     AS gam_wait_ms_now,
    ac.sgam_wait_ms_now                                    AS sgam_wait_ms_now,
    -- Verdict text — useful for an alert subject
    CASE
        WHEN 100.0 * (fu.user_object_pages + fu.internal_object_pages
                      + fu.version_store_pages) * 8
             / NULLIF(fs.total_kb, 0) > 90
            THEN N'🔴 tempdb >90% used'
        WHEN ac.pages_in_alloc_wait > 5
            THEN N'🟠 multiple sessions waiting on tempdb allocation pages'
        WHEN 100.0 * (fu.user_object_pages + fu.internal_object_pages
                      + fu.version_store_pages) * 8
             / NULLIF(fs.total_kb, 0) > 70
            THEN N'🟡 tempdb >70% used'
        ELSE NULL
    END                                                    AS verdict
FROM file_size              AS fs
CROSS JOIN file_usage       AS fu
CROSS JOIN allocation_contention AS ac;
