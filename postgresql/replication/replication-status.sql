-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : replication-status                              ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : replication                                     ║
-- ║  Impact        : 🟢 Light  (catalog views only)                   ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_replication_slots║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-replication-status║
-- ║  Inspired by   : pg_stat_replication / pg_replication_slots —    ║
-- ║                  PostgreSQL official docs.                       ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-02-17                                      ║
-- ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Three sections in one result set:
--   1. ROLE          — am I a primary or a standby?
--   2. STANDBYS      — pg_stat_replication: connected replicas, lag.
--   3. SLOTS         — pg_replication_slots: physical / logical slots,
--                      retained WAL, whether they're active.
--
-- Run this on the *primary* for the full picture. On a standby, the
-- ROLE section will show STANDBY and the STANDBYS / SLOTS sections will
-- typically be empty.

-- ── ROLE ────────────────────────────────────────────────────────────
SELECT
    'ROLE'                                                   AS section,
    CASE WHEN pg_is_in_recovery() THEN 'STANDBY' ELSE 'PRIMARY' END AS metric,
    CASE
        WHEN pg_is_in_recovery() THEN
            coalesce(pg_last_wal_receive_lsn()::text, '<n/a>')
            || ' / '
            || coalesce(pg_last_wal_replay_lsn()::text, '<n/a>')
        ELSE pg_current_wal_lsn()::text
    END                                                      AS value,
    CASE
        WHEN pg_is_in_recovery() THEN
            'receive_lsn / replay_lsn'
        ELSE 'current_wal_lsn on primary'
    END                                                      AS note;

-- ── STANDBYS ────────────────────────────────────────────────────────
SELECT
    'STANDBYS'                                               AS section,
    coalesce(application_name, '<unset>')                    AS metric,
    coalesce(client_addr::text, '<local>')
    || ' (' || coalesce(state, 'unknown') || ')'             AS value,
    CASE
        WHEN write_lag IS NOT NULL THEN
            'write ' || write_lag::text
            || ' | flush ' || coalesce(flush_lag::text, 'n/a')
            || ' | replay ' || coalesce(replay_lag::text, 'n/a')
        ELSE 'lag intervals not reported'
    END                                                      AS note
FROM pg_stat_replication
ORDER BY application_name;

-- ── SLOTS ───────────────────────────────────────────────────────────
SELECT
    'SLOTS'                                                  AS section,
    slot_name                                                AS metric,
    slot_type
    || ' | active=' || active::text
    || ' | restart_lsn=' || coalesce(restart_lsn::text, '<null>') AS value,
    CASE
        WHEN active = false THEN
            'inactive slot — retains WAL forever, can fill the disk'
        WHEN restart_lsn IS NULL THEN
            'no restart_lsn yet'
        ELSE
            'WAL retained: '
            || pg_size_pretty(
                pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
            )
    END                                                      AS note
FROM pg_replication_slots
ORDER BY slot_name;
