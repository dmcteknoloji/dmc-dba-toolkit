-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : innodb-trx-deep                                 ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟡 Medium  (joins INNODB_TRX with multiple views)║
-- ║  Permissions   : PROCESS privilege; SELECT on information_schema  ║
-- ║                  and performance_schema                           ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-innodb-trx-deep  ║
-- ║  Inspired by   : MySQL Reference Manual — INNODB_TRX, data_locks, ║
-- ║                  data_lock_waits cross-references.                 ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (deep cross-DMV analysis of every live txn) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Long-running InnoDB transactions are the source of half of
--       the "MySQL is slow" calls. They hold undo records, prevent
--       purge, hold locks across statements and accumulate row
--       locks that are invisible until the next deadlock. SHOW
--       ENGINE INNODB STATUS\G is human-readable but unstructured.
--       This script joins INNODB_TRX with data_locks and processlist
--       to produce a row per live transaction with: age, lock count,
--       isolation level, the statement currently running, and the
--       connection that owns it.
--   TR: Uzun süreli InnoDB transaction'ları "MySQL yavaş"
--       çağrılarının yarısının kaynağıdır. Undo kayıtları tutar,
--       purge'ı engeller, statement'lar arasında lock taşır ve
--       sonraki deadlock'a kadar görünmeyen row lock'lar biriktirir.
--       SHOW ENGINE INNODB STATUS\G okunabilir ama yapılandırılmamış.
--       Bu script INNODB_TRX'i data_locks ve processlist ile join'leyerek
--       canlı her transaction için satır üretir: yaş, kilit sayısı,
--       isolation level, şu an çalışan statement ve sahibi bağlantı.

SELECT
    trx.trx_id                                                      AS trx_id,
    trx.trx_state                                                   AS state,
    trx.trx_started                                                 AS started_at,
    TIMESTAMPDIFF(SECOND, trx.trx_started, NOW(6))                  AS age_secs,
    trx.trx_isolation_level                                         AS isolation_level,
    -- Operation accounting
    trx.trx_lock_structs                                            AS lock_structs,
    trx.trx_rows_locked                                             AS rows_locked,
    trx.trx_rows_modified                                           AS rows_modified,
    trx.trx_lock_memory_bytes                                       AS lock_memory_bytes,
    -- Concurrency state
    trx.trx_concurrency_tickets                                     AS concurrency_tickets,
    trx.trx_unique_checks                                           AS unique_checks,
    trx.trx_foreign_key_checks                                      AS fk_checks,
    -- The connection (thread) running this transaction
    trx.trx_mysql_thread_id                                         AS mysql_thread_id,
    pl.HOST                                                         AS client_host,
    pl.USER                                                         AS user_name,
    pl.DB                                                           AS connected_db,
    pl.COMMAND                                                      AS thread_command,
    pl.STATE                                                        AS thread_state,
    -- The statement currently running for the connection (may be NULL
    -- if the transaction is open but no statement is currently active —
    -- the canonical "idle in transaction" pattern).
    LEFT(IFNULL(trx.trx_query, '<idle in transaction>'), 200)       AS current_statement,
    -- Wait state — if this transaction is itself blocked on a lock
    trx.trx_wait_started                                            AS wait_started,
    CASE WHEN trx.trx_wait_started IS NOT NULL
         THEN TIMESTAMPDIFF(SECOND, trx.trx_wait_started, NOW(6))
    END                                                             AS waiting_secs,
    trx.trx_requested_lock_id                                       AS waiting_for_lock_id,
    -- Cross-reference: is this transaction holding locks others want?
    (SELECT COUNT(*)
     FROM performance_schema.data_lock_waits AS w
     WHERE w.BLOCKING_THREAD_ID = ps_t.THREAD_ID)                   AS sessions_blocked_by_this,
    -- Verdict — single line per row, makes the result triage-ready
    CASE
        WHEN TIMESTAMPDIFF(SECOND, trx.trx_started, NOW(6)) > 3600
            THEN '🔴 transaction running >1h — undo bloat + lock retention'
        WHEN trx.trx_query IS NULL
             AND TIMESTAMPDIFF(SECOND, trx.trx_started, NOW(6)) > 300
            THEN '🟠 idle in transaction >5 min — application forgot to commit'
        WHEN trx.trx_wait_started IS NOT NULL
             AND TIMESTAMPDIFF(SECOND, trx.trx_wait_started, NOW(6)) > 30
            THEN '🟠 waiting on lock >30s'
        WHEN trx.trx_rows_locked > 100000
            THEN '🟠 holds locks on >100k rows — large scope'
    END                                                             AS verdict
FROM information_schema.INNODB_TRX                                  AS trx
LEFT JOIN performance_schema.processlist                            AS pl
    ON pl.ID = trx.trx_mysql_thread_id
LEFT JOIN performance_schema.threads                                AS ps_t
    ON ps_t.PROCESSLIST_ID = trx.trx_mysql_thread_id
ORDER BY age_secs DESC;
