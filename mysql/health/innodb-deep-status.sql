-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : innodb-deep-status                              ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟡 Medium  (multiple INFORMATION_SCHEMA scans)   ║
-- ║  Permissions   : PROCESS privilege; SELECT on information_schema ║
-- ║                  and performance_schema                           ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-innodb-deep-status ║
-- ║  Inspired by   : Mark Callaghan's public InnoDB deep-dive posts,  ║
-- ║                  Jeremy Cole's innodb internals reference, and    ║
-- ║                  the official MySQL Reference Manual InnoDB        ║
-- ║                  monitoring chapter. Technique credited.          ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (semaphore + buffer pool + log + adaptive hash) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   SHOW ENGINE INNODB STATUS\G çıktısının parse edilmiş, yapılandırılmış
--   versiyonu — sadece headline counter'lar değil, semaphore wait'leri,
--   adaptive hash index hit oranı, redo log baskısı, undo / history
--   list uzunluğu da dahil. Tek bir INFORMATION_SCHEMA / global_status
--   sorgusuyla halledebileceğin için INNODB STATUS metnini parse
--   etmek zorunda kalmazsın. Yüksek history list length = MVCC
--   geri kalmış, undo şişiyor demektir — purge thread'lerin yetişmesi
--   gerek.
--
-- Why this exists:
--   The text output of SHOW ENGINE INNODB STATUS is rich but
--   unstructured — you can't trend it, you can't alert on a specific
--   counter, and you have to grep through it during incidents.
--   Almost every value in that text is also reachable via either
--   information_schema.INNODB_METRICS or performance_schema's status
--   counters. This script returns the most-asked-after of those in
--   a single result, ready for a target table.

-- ── 1. SEMAPHORE WAITS — concurrency stress signal ─────────────────
SELECT
    NOW(6)                                                              AS sample_utc,
    'SEMAPHORES'                                                        AS section,
    NAME                                                                AS metric,
    COUNT_RESET                                                         AS value,
    STATUS                                                              AS status,
    SUBSYSTEM
FROM information_schema.INNODB_METRICS
WHERE NAME IN (
    'innodb_rwlock_s_spin_waits',
    'innodb_rwlock_s_spin_rounds',
    'innodb_rwlock_s_os_waits',
    'innodb_rwlock_x_spin_waits',
    'innodb_rwlock_x_spin_rounds',
    'innodb_rwlock_x_os_waits'
)
ORDER BY NAME;

-- ── 2. BUFFER POOL — internals beyond the basic snapshot ──────────
SELECT
    'BUFFER_POOL_DEEP'                                                  AS section,
    POOL_ID                                                             AS pool_id,
    POOL_SIZE                                                           AS pool_pages,
    DATABASE_PAGES                                                      AS data_pages,
    OLD_DATABASE_PAGES                                                  AS old_data_pages,
    MODIFIED_DATABASE_PAGES                                             AS dirty_pages,
    PENDING_DECOMPRESS                                                  AS pending_decompress,
    PENDING_READS                                                       AS pending_reads,
    PENDING_FLUSH_LRU                                                   AS pending_flush_lru,
    PENDING_FLUSH_LIST                                                  AS pending_flush_list,
    -- The young-page promotion ratio. High values mean fresh pages
    -- are being promoted to the "old sublist" too quickly — index
    -- scans evicting hot data.
    PAGES_MADE_YOUNG                                                    AS pages_made_young_cum,
    PAGES_NOT_MADE_YOUNG                                                AS pages_not_made_young_cum,
    -- LRU read-ahead efficiency
    READ_AHEAD                                                          AS read_ahead_cum,
    READ_AHEAD_EVICTED                                                  AS read_ahead_evicted_cum
FROM information_schema.INNODB_BUFFER_POOL_STATS
ORDER BY POOL_ID;

-- ── 3. REDO LOG — write pressure ──────────────────────────────────
SELECT
    'REDO_LOG'                                                          AS section,
    VARIABLE_NAME                                                       AS metric,
    VARIABLE_VALUE                                                      AS value
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Innodb_log_writes',
    'Innodb_log_write_requests',
    'Innodb_os_log_fsyncs',
    'Innodb_os_log_pending_fsyncs',
    'Innodb_os_log_pending_writes',
    'Innodb_os_log_written'
)
ORDER BY VARIABLE_NAME;

-- ── 4. UNDO / HISTORY LIST — MVCC backlog ─────────────────────────
-- A high history list length indicates long-running transactions
-- preventing the purge threads from removing old row versions.
-- Comparable to PG's xmin holder problem.
SELECT
    'HISTORY_LIST'                                                      AS section,
    'history_list_length'                                               AS metric,
    COUNT_RESET                                                         AS value,
    CASE
        WHEN COUNT_RESET > 1000000
            THEN '🔴 history list > 1M — long-running transaction blocking purge'
        WHEN COUNT_RESET > 100000
            THEN '🟠 history list > 100k — purge falling behind'
    END                                                                 AS verdict
FROM information_schema.INNODB_METRICS
WHERE NAME = 'trx_rseg_history_len';

-- ── 5. ADAPTIVE HASH INDEX ────────────────────────────────────────
-- Disabled adaptive hash index can be a deliberate choice on
-- write-heavy workloads, but its hit ratio is still useful telemetry.
SELECT
    'AHI'                                                               AS section,
    NAME                                                                AS metric,
    COUNT_RESET                                                         AS value
FROM information_schema.INNODB_METRICS
WHERE NAME IN (
    'adaptive_hash_searches',
    'adaptive_hash_searches_btree',
    'adaptive_hash_pages_added',
    'adaptive_hash_pages_removed',
    'adaptive_hash_rows_added',
    'adaptive_hash_rows_removed'
)
ORDER BY NAME;

-- ── 6. ROW OPERATIONS — per-second proxies (cumulative) ───────────
SELECT
    'ROW_OPS'                                                           AS section,
    VARIABLE_NAME                                                       AS metric,
    VARIABLE_VALUE                                                      AS value
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Innodb_rows_inserted',
    'Innodb_rows_updated',
    'Innodb_rows_deleted',
    'Innodb_rows_read',
    'Innodb_pages_read',
    'Innodb_pages_written'
)
ORDER BY VARIABLE_NAME;
