-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : lock-mode-conflict-matrix                       ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : blocking                                        ║
-- ║  Impact        : 🟢 Light  (pg_locks + pg_stat_activity scan)     ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_locks            ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-lock-mode-conflict-matrix ║
-- ║  Inspired by   : PostgreSQL official docs — Explicit Locking      ║
-- ║                  chapter (lock mode compatibility table). Code    ║
-- ║                  original; the matrix lookup is implemented as a  ║
-- ║                  VALUES list rather than relying on an extension. ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (lock-mode internals + recursive resolution) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: pg_blocking_pids() answers "who is blocking whom" but it
--       doesn't tell you *why* — which lock mode held by the blocker
--       conflicts with which mode the waiter wants. Production
--       deadlocks and unexpected blocks frequently come from
--       AccessExclusive vs RowExclusive surprises (DDL during
--       traffic). This script joins pg_locks against itself to
--       surface the held-mode × requested-mode pair for every
--       blocked relation, and uses the official conflict matrix
--       (Concurrency Control chapter) to explain the conflict.
--   TR: pg_blocking_pids() "kim kimi bloklar" sorusunu cevaplar ama
--       *neden* sorusunu cevaplamaz — bloker'ın tuttuğu hangi lock
--       mode bekleyenin istediği mode ile çatışıyor? Production
--       deadlock ve beklenmedik bloklar çoğunlukla AccessExclusive
--       vs RowExclusive sürprizlerinden gelir (trafik altında DDL).
--       Bu script pg_locks'ı kendisiyle join'leyerek her bloklu
--       relation için tutulan-mode × istenilen-mode çiftini çıkarır
--       ve resmi conflict matrix'i (Concurrency Control bölümü)
--       kullanarak çatışmayı açıklar.

-- ── 1. PG LOCK CONFLICT MATRIX (from official docs) ────────────────
-- This VALUES list is the canonical compatibility table.
-- Reference: PostgreSQL Reference Manual — Explicit Locking, Table
-- "Conflicting Lock Modes". Rows = held; columns = requested.
WITH conflict_matrix AS (
    SELECT held, requested, conflicts
    FROM (VALUES
        -- AccessShare conflicts only with AccessExclusive
        ('AccessShareLock', 'AccessShareLock', false),
        ('AccessShareLock', 'RowShareLock', false),
        ('AccessShareLock', 'RowExclusiveLock', false),
        ('AccessShareLock', 'ShareUpdateExclusiveLock', false),
        ('AccessShareLock', 'ShareLock', false),
        ('AccessShareLock', 'ShareRowExclusiveLock', false),
        ('AccessShareLock', 'ExclusiveLock', false),
        ('AccessShareLock', 'AccessExclusiveLock', true),
        -- RowShare
        ('RowShareLock', 'AccessShareLock', false),
        ('RowShareLock', 'RowShareLock', false),
        ('RowShareLock', 'RowExclusiveLock', false),
        ('RowShareLock', 'ShareUpdateExclusiveLock', false),
        ('RowShareLock', 'ShareLock', false),
        ('RowShareLock', 'ShareRowExclusiveLock', false),
        ('RowShareLock', 'ExclusiveLock', true),
        ('RowShareLock', 'AccessExclusiveLock', true),
        -- RowExclusive — the mode INSERT/UPDATE/DELETE acquire
        ('RowExclusiveLock', 'AccessShareLock', false),
        ('RowExclusiveLock', 'RowShareLock', false),
        ('RowExclusiveLock', 'RowExclusiveLock', false),
        ('RowExclusiveLock', 'ShareUpdateExclusiveLock', false),
        ('RowExclusiveLock', 'ShareLock', true),
        ('RowExclusiveLock', 'ShareRowExclusiveLock', true),
        ('RowExclusiveLock', 'ExclusiveLock', true),
        ('RowExclusiveLock', 'AccessExclusiveLock', true),
        -- ShareUpdateExclusive — VACUUM, ANALYZE, CREATE INDEX CONCURRENTLY
        ('ShareUpdateExclusiveLock', 'AccessShareLock', false),
        ('ShareUpdateExclusiveLock', 'RowShareLock', false),
        ('ShareUpdateExclusiveLock', 'RowExclusiveLock', false),
        ('ShareUpdateExclusiveLock', 'ShareUpdateExclusiveLock', true),
        ('ShareUpdateExclusiveLock', 'ShareLock', true),
        ('ShareUpdateExclusiveLock', 'ShareRowExclusiveLock', true),
        ('ShareUpdateExclusiveLock', 'ExclusiveLock', true),
        ('ShareUpdateExclusiveLock', 'AccessExclusiveLock', true),
        -- Share — CREATE INDEX (without CONCURRENTLY)
        ('ShareLock', 'AccessShareLock', false),
        ('ShareLock', 'RowShareLock', false),
        ('ShareLock', 'RowExclusiveLock', true),
        ('ShareLock', 'ShareUpdateExclusiveLock', true),
        ('ShareLock', 'ShareLock', false),
        ('ShareLock', 'ShareRowExclusiveLock', true),
        ('ShareLock', 'ExclusiveLock', true),
        ('ShareLock', 'AccessExclusiveLock', true),
        -- ShareRowExclusive
        ('ShareRowExclusiveLock', 'AccessShareLock', false),
        ('ShareRowExclusiveLock', 'RowShareLock', false),
        ('ShareRowExclusiveLock', 'RowExclusiveLock', true),
        ('ShareRowExclusiveLock', 'ShareUpdateExclusiveLock', true),
        ('ShareRowExclusiveLock', 'ShareLock', true),
        ('ShareRowExclusiveLock', 'ShareRowExclusiveLock', true),
        ('ShareRowExclusiveLock', 'ExclusiveLock', true),
        ('ShareRowExclusiveLock', 'AccessExclusiveLock', true),
        -- Exclusive
        ('ExclusiveLock', 'AccessShareLock', false),
        ('ExclusiveLock', 'RowShareLock', true),
        ('ExclusiveLock', 'RowExclusiveLock', true),
        ('ExclusiveLock', 'ShareUpdateExclusiveLock', true),
        ('ExclusiveLock', 'ShareLock', true),
        ('ExclusiveLock', 'ShareRowExclusiveLock', true),
        ('ExclusiveLock', 'ExclusiveLock', true),
        ('ExclusiveLock', 'AccessExclusiveLock', true),
        -- AccessExclusive — DDL, conflicts with everything
        ('AccessExclusiveLock', 'AccessShareLock', true),
        ('AccessExclusiveLock', 'RowShareLock', true),
        ('AccessExclusiveLock', 'RowExclusiveLock', true),
        ('AccessExclusiveLock', 'ShareUpdateExclusiveLock', true),
        ('AccessExclusiveLock', 'ShareLock', true),
        ('AccessExclusiveLock', 'ShareRowExclusiveLock', true),
        ('AccessExclusiveLock', 'ExclusiveLock', true),
        ('AccessExclusiveLock', 'AccessExclusiveLock', true)
    ) AS m(held, requested, conflicts)
),
-- ── 2. CURRENT WAITS WITH HOLDER × WAITER MODE PAIRS ───────────────
held_locks AS (
    SELECT pid, locktype, relation, mode AS held_mode, granted, transactionid
    FROM pg_locks
    WHERE granted
),
waited_locks AS (
    SELECT pid, locktype, relation, mode AS requested_mode, granted, transactionid
    FROM pg_locks
    WHERE NOT granted
)
SELECT
    w.pid                                                       AS waiter_pid,
    h.pid                                                       AS holder_pid,
    coalesce(c_w.relname, '<txn-id wait>')                      AS object_name,
    coalesce(n_w.nspname, '<txn-id wait>')                      AS schema_name,
    w.locktype                                                  AS wait_lock_type,
    w.requested_mode                                            AS waiter_wants,
    h.held_mode                                                 AS holder_holds,
    cm.conflicts                                                AS modes_conflict,
    -- Holder + waiter context — lifted from pg_stat_activity.
    a_w.usename                                                 AS waiter_user,
    a_w.application_name                                        AS waiter_app,
    a_h.usename                                                 AS holder_user,
    a_h.application_name                                        AS holder_app,
    a_w.state                                                   AS waiter_state,
    a_h.state                                                   AS holder_state,
    round(extract(epoch FROM (now() - a_w.query_start))::numeric, 1)
                                                                AS waiter_query_age_secs,
    round(extract(epoch FROM (now() - a_h.xact_start))::numeric, 1)
                                                                AS holder_xact_age_secs,
    -- Verdict — combines mode pair and behaviour into a single line
    CASE
        WHEN h.held_mode = 'AccessExclusiveLock'
            THEN '🔴 holder has AccessExclusive — likely DDL during traffic'
        WHEN h.held_mode = 'ShareLock' AND w.requested_mode = 'RowExclusiveLock'
            THEN '🟠 CREATE INDEX (Share) blocking writes (RowExclusive)'
        WHEN a_h.state = 'idle in transaction'
            THEN '🟠 holder is idle-in-xact — application forgot to commit'
        WHEN a_h.state = 'active'
            AND extract(epoch FROM (now() - a_h.query_start)) > 300
            THEN '🟠 holder query running >5 min'
    END                                                         AS note,
    -- Truncated query previews
    left(a_w.query, 200)                                        AS waiter_query,
    left(a_h.query, 200)                                        AS holder_query
FROM waited_locks                       AS w
JOIN held_locks                         AS h
    ON h.locktype = w.locktype
    AND ((h.relation = w.relation AND h.relation IS NOT NULL)
         OR (h.transactionid = w.transactionid AND h.transactionid IS NOT NULL))
    AND h.pid <> w.pid
JOIN conflict_matrix                    AS cm
    ON cm.held = h.held_mode AND cm.requested = w.requested_mode
   AND cm.conflicts
LEFT JOIN pg_class                      AS c_w  ON c_w.oid = w.relation
LEFT JOIN pg_namespace                  AS n_w  ON n_w.oid = c_w.relnamespace
LEFT JOIN pg_stat_activity              AS a_w  ON a_w.pid = w.pid
LEFT JOIN pg_stat_activity              AS a_h  ON a_h.pid = h.pid
ORDER BY a_w.query_start NULLS LAST;
