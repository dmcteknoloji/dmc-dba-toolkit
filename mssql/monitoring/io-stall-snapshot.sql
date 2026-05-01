-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : io-stall-snapshot                               ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (single DMV scan, milliseconds)        ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-io-stall-snapshot ║
-- ║  Inspired by   : sys.dm_io_virtual_file_stats reference —        ║
-- ║                  Microsoft Learn public docs. The Paul Randal     ║
-- ║                  diff-the-snapshots methodology shaped the        ║
-- ║                  per-file aggregation approach.                   ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (per-file IO + average latency derivation) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Her DB dosyası için kümülatif IO stall (ms) ve sayım'larını
--   döner; ms / IO bölümü ortalama latency'yi verir. SQL Server'ın
--   "diskim yavaş" dediğinin canonical kanıtıdır. Tek satır snapshot
--   — periyodik çalıştırıp diff alarak trend kur. Yüksek
--   read_stall_avg_ms_per_io storage'ın okuyamadığını, yüksek
--   write_stall_avg ise yazamadığını söyler. Tempdb'nin diğer
--   DB'lerden ayrılması için bir göstergedir bu.
--
-- Why this exists:
--   "The disk is slow" is hard to confirm without per-file evidence.
--   sys.dm_io_virtual_file_stats records cumulative read/write count
--   and stall (the time waiting on IO) per database file since
--   instance startup. Dividing stall by IO gives average latency in
--   ms per IO — the number storage vendors and DBAs actually argue
--   over. This script keeps the per-file shape so you can see which
--   files are contributing the worst latency.

SELECT
    SYSUTCDATETIME()                                             AS sample_utc,
    @@SERVERNAME                                                 AS server_name,
    DB_NAME(vfs.database_id)                                     AS database_name,
    vfs.file_id                                                  AS file_id,
    mf.name                                                      AS logical_name,
    mf.physical_name                                             AS physical_path,
    mf.type_desc                                                 AS file_type,
    -- Cumulative since startup
    vfs.num_of_reads                                             AS reads_cumulative,
    vfs.num_of_writes                                            AS writes_cumulative,
    vfs.num_of_bytes_read                                        AS bytes_read_cumulative,
    vfs.num_of_bytes_written                                     AS bytes_written_cumulative,
    vfs.io_stall_read_ms                                         AS read_stall_ms_cumulative,
    vfs.io_stall_write_ms                                        AS write_stall_ms_cumulative,
    vfs.io_stall                                                 AS total_stall_ms_cumulative,
    -- Average latency since startup — diff externally for instant rate
    CAST(vfs.io_stall_read_ms * 1.0
         / NULLIF(vfs.num_of_reads, 0)
         AS DECIMAL(18, 2))                                      AS read_stall_avg_ms_per_io,
    CAST(vfs.io_stall_write_ms * 1.0
         / NULLIF(vfs.num_of_writes, 0)
         AS DECIMAL(18, 2))                                      AS write_stall_avg_ms_per_io,
    -- Throughput proxy
    CAST(vfs.num_of_bytes_read * 1.0
         / NULLIF(vfs.num_of_reads, 0)
         / 1024
         AS DECIMAL(18, 2))                                      AS avg_read_kb_per_io,
    CAST(vfs.num_of_bytes_written * 1.0
         / NULLIF(vfs.num_of_writes, 0)
         / 1024
         AS DECIMAL(18, 2))                                      AS avg_write_kb_per_io,
    -- Verdict — combines latency + volume into a single line
    CASE
        WHEN vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) > 50
            AND vfs.num_of_reads > 1000
            THEN N'🔴 read latency > 50 ms/IO with >1k reads — disk under stress'
        WHEN vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) > 50
            AND vfs.num_of_writes > 1000
            THEN N'🔴 write latency > 50 ms/IO with >1k writes — investigate'
        WHEN vfs.io_stall_read_ms / NULLIF(vfs.num_of_reads, 0) > 20
            THEN N'🟠 read latency > 20 ms/IO — sub-optimal but not critical'
        WHEN vfs.io_stall_write_ms / NULLIF(vfs.num_of_writes, 0) > 20
            THEN N'🟠 write latency > 20 ms/IO — sub-optimal'
    END                                                          AS verdict
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN sys.master_files                          AS mf
    ON mf.database_id = vfs.database_id
    AND mf.file_id = vfs.file_id
ORDER BY vfs.io_stall DESC;
