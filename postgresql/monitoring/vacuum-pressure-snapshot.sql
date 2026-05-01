-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : vacuum-pressure-snapshot                        ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (catalog views only)                   ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_stat_*          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-vacuum-pressure-snapshot ║
-- ║  Inspired by   : pg_stat_user_tables, pg_stat_progress_vacuum —  ║
-- ║                  PostgreSQL official monitoring docs.             ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (output requires deep DMV / internals knowledge)      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Autovacuum running behind is the slow-motion incident that
--       turns into "the disk is full, the queries are slow, the
--       transaction wraparound counter is approaching the cliff".
--       This snapshot tracks the four signals that predict the
--       cliff: dead-tuple ratio on the worst tables, age of the
--       oldest unfrozen xid, count of vacuums currently running,
--       and the long-running transaction that's blocking xmin.
--   TR: Geride kalan autovacuum, "disk doldu, sorgular yavaş,
--       transaction wraparound sayacı uçuruma yaklaşıyor"a dönüşen
--       ağır çekim incident'tır. Bu snapshot uçurumu öngören dört
--       sinyali izler: en kötü tablolardaki ölü-tuple oranı, en eski
--       unfrozen xid'in yaşı, anlık çalışan vacuum sayısı ve xmin'i
--       bloklayan uzun-süreli transaction.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 charts vacuum lag per database, alerts before
--   wraparound becomes urgent, and identifies the long transaction
--   holding xmin — see https://github.com/dmcteknoloji.

WITH worst_tables AS (
    SELECT
        schemaname,
        relname,
        n_live_tup,
        n_dead_tup,
        last_vacuum,
        last_autovacuum,
        n_dead_tup * 1.0 / NULLIF(n_live_tup, 0) AS dead_ratio
    FROM pg_stat_user_tables
    WHERE n_live_tup > 1000   -- ignore tiny tables
)
SELECT
    now()                                                          AS sample_utc,
    current_database()                                             AS database_name,
    -- Top dead-tuple ratio (most-bloated logical row table)
    (SELECT max(dead_ratio) FROM worst_tables)                    AS worst_dead_ratio,
    (SELECT relname FROM worst_tables
     WHERE dead_ratio = (SELECT max(dead_ratio) FROM worst_tables)
     LIMIT 1)                                                     AS worst_dead_ratio_table,
    -- Aggregate dead tuple counts
    (SELECT sum(n_dead_tup) FROM worst_tables)                    AS total_dead_tuples,
    (SELECT sum(n_live_tup) FROM worst_tables)                    AS total_live_tuples,
    -- Oldest "unfrozen" xid age — wraparound is at 2 billion.
    -- This is the metric Postgres itself watches for the warning.
    (SELECT max(age(datfrozenxid))
     FROM pg_database
     WHERE datname = current_database())                          AS oldest_xid_age,
    -- Transaction xmin — long-running transactions hold this back
    -- and prevent vacuum from removing dead tuples newer than xmin.
    (SELECT min(backend_xmin)
     FROM pg_stat_activity
     WHERE backend_xmin IS NOT NULL)::text                        AS oldest_xmin_holder,
    (SELECT round(extract(epoch FROM (now() - xact_start))::numeric, 1)
     FROM pg_stat_activity
     WHERE backend_xmin IS NOT NULL
     ORDER BY xact_start ASC
     LIMIT 1)                                                     AS oldest_xmin_xact_age_secs,
    -- Vacuums currently running (PG13+: pg_stat_progress_vacuum)
    (SELECT count(*) FROM pg_stat_progress_vacuum)                AS vacuums_running_now,
    (SELECT count(*) FROM pg_stat_progress_vacuum
     WHERE phase = 'scanning heap')                               AS vacuums_scanning_heap,
    -- Autovacuum settings (so the alert subject can include them)
    current_setting('autovacuum')                                 AS autovacuum_setting,
    current_setting('autovacuum_max_workers')                     AS autovacuum_max_workers,
    -- Verdict text — one line for an alert subject
    CASE
        WHEN (SELECT max(age(datfrozenxid)) FROM pg_database
              WHERE datname = current_database()) > 1500000000
            THEN '🔴 xid age >1.5B — wraparound risk approaching'
        WHEN (SELECT max(dead_ratio) FROM worst_tables) > 0.5
            THEN '🟠 a table is >50% dead tuples — vacuum running behind'
        WHEN (SELECT round(extract(epoch FROM (now() - xact_start))::numeric, 1)
              FROM pg_stat_activity
              WHERE backend_xmin IS NOT NULL
              ORDER BY xact_start ASC LIMIT 1) > 1800
            THEN '🟠 xmin holder transaction running >30 min — blocks vacuum cleanup'
        ELSE NULL
    END                                                           AS verdict;
