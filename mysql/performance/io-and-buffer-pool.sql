-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : io-and-buffer-pool                              ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (status counters + INNODB views)       ║
-- ║  Permissions   : SELECT on performance_schema, sys schema        ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-io-and-buffer-pool ║
-- ║  Inspired by   : INNODB_BUFFER_POOL_STATS, sys.io_global_by_*    ║
-- ║                  views — MySQL Reference Manual.                  ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-16                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Buffer pool hit rate is the headline number people quote, but
--       it's often misleading — a 99.5% hit rate on a 1 TB working set
--       still means 50 GB of physical reads. The real signals are
--       four: (1) absolute miss count over time, (2) read vs write
--       breakdown, (3) which files dominate IO, and (4) dirty page
--       ratio. This script returns all four and adds the per-buffer-
--       pool-instance view (8.0+) so you can spot uneven warmup.
--   TR: Buffer pool hit oranı manşet rakamıdır ama çoğu zaman yanıltır;
--       1 TB working set üstünde %99.5 hit oranı bile 50 GB fiziksel
--       okuma demektir. Asıl sinyaller dört tane: (1) zaman içinde
--       mutlak miss sayısı, (2) okuma/yazma kırılımı, (3) IO'yu
--       hangi dosyaların domine ettiği, (4) dirty page oranı. Bu
--       script dördünü de döndürür ve 8.0+ için per-instance görünüm
--       ekler — eşit olmayan warmup'ı yakalamak için.

-- ── 1. BUFFER POOL HEADLINE ────────────────────────────────────────
SELECT
    'HEADLINE'                                                     AS section,
    'buffer_pool_size_mb'                                          AS metric,
    CAST(@@innodb_buffer_pool_size / 1048576 AS CHAR)              AS value,
    NULL                                                           AS note
UNION ALL
SELECT 'HEADLINE', 'buffer_pool_instances',
       CAST(@@innodb_buffer_pool_instances AS CHAR),
       CASE WHEN @@innodb_buffer_pool_size >= 8589934592   -- 8 GB
                 AND @@innodb_buffer_pool_instances < 8
            THEN '8 GB+ pool with <8 instances — consider raising for scalability'
            ELSE NULL END
UNION ALL
SELECT 'HEADLINE', 'buffer_pool_pages_total',
       VARIABLE_VALUE, NULL
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_total'
UNION ALL
SELECT 'HEADLINE', 'buffer_pool_pages_dirty',
       VARIABLE_VALUE,
       'dirty pages waiting to flush — high values often indicate IO bottleneck or aggressive innodb_max_dirty_pages_pct'
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_buffer_pool_pages_dirty';

-- ── 2. HIT RATE WITH ABSOLUTE NUMBERS ──────────────────────────────
SELECT
    'HIT_RATE'                                                     AS section,
    reqs.VARIABLE_VALUE                                            AS read_requests,
    misses.VARIABLE_VALUE                                          AS read_misses_to_disk,
    -- absolute miss count over uptime — this is the number that scales
    ROUND(misses.VARIABLE_VALUE / NULLIF(uptime.VARIABLE_VALUE, 0), 2)
                                                                   AS misses_per_second,
    ROUND(100.0 * (1 - misses.VARIABLE_VALUE
                       / NULLIF(reqs.VARIABLE_VALUE, 0)), 4)       AS hit_rate_pct,
    CASE
        WHEN misses.VARIABLE_VALUE / NULLIF(uptime.VARIABLE_VALUE, 0) > 1000
            THEN '🔴 >1000 misses/sec — buffer pool likely undersized for the working set'
        WHEN misses.VARIABLE_VALUE / NULLIF(uptime.VARIABLE_VALUE, 0) > 100
            THEN '🟠 >100 misses/sec — review working set vs pool size'
    END                                                            AS note
FROM (SELECT VARIABLE_VALUE FROM performance_schema.global_status
      WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') AS reqs,
     (SELECT VARIABLE_VALUE FROM performance_schema.global_status
      WHERE VARIABLE_NAME='Innodb_buffer_pool_reads')         AS misses,
     (SELECT VARIABLE_VALUE FROM performance_schema.global_status
      WHERE VARIABLE_NAME='Uptime')                           AS uptime;

-- ── 3. PER-INSTANCE WARMUP (8.0+) ──────────────────────────────────
-- Multiple buffer pool instances should warm up evenly. Wide divergence
-- between instances indicates partition skew on the access pattern.
SELECT
    'PER_INSTANCE'                                                 AS section,
    POOL_ID                                                        AS pool_id,
    POOL_SIZE                                                      AS pool_pages,
    DATABASE_PAGES                                                 AS data_pages,
    FREE_BUFFERS                                                   AS free_pages,
    MODIFIED_DATABASE_PAGES                                        AS dirty_pages,
    ROUND(100.0 * DATABASE_PAGES / POOL_SIZE, 1)                   AS pct_full,
    ROUND(100.0 * MODIFIED_DATABASE_PAGES
          / NULLIF(DATABASE_PAGES, 0), 2)                          AS pct_dirty,
    HIT_RATE                                                       AS hit_rate_per_thousand
FROM information_schema.INNODB_BUFFER_POOL_STATS
ORDER BY POOL_ID;

-- ── 4. TOP IO FILES (sys schema, 5.7+) ─────────────────────────────
SELECT
    'TOP_IO_FILES'                                                 AS section,
    file                                                           AS file_path,
    count_read                                                     AS reads,
    sys.format_bytes(total_read)                                   AS total_read,
    count_write                                                    AS writes,
    sys.format_bytes(total_written)                                AS total_written,
    sys.format_bytes(total_read + total_written)                   AS total_io
FROM sys.io_global_by_file_by_bytes
ORDER BY total_read + total_written DESC
LIMIT 15;
