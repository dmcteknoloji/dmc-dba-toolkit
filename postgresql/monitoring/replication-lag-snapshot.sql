-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : replication-lag-snapshot                        ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (catalog views only)                   ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_stat_replication║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-replication-lag-snapshot ║
-- ║  Inspired by   : pg_stat_replication, pg_replication_slots —    ║
-- ║                  PostgreSQL official docs.                        ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Replication lag is a leading indicator. Plot it over time
--       and the day a replica starts to fall behind shows up as a
--       clean curve — usually 24-72 hours before the report
--       consumer notices. This snapshot returns the worst-case lag
--       in bytes plus a count of standbys whose lag exceeds a
--       threshold. Standby members that disconnect entirely show
--       up as a drop in `connected_standbys`.
--   TR: Replication lag erken göstergedir. Zaman içinde grafiğe
--       döktüğünde, bir replikanın geride kalmaya başladığı gün
--       temiz bir eğri olarak çıkar — genelde rapor tüketicisinin
--       fark etmesinden 24-72 saat önce. Bu snapshot byte cinsinden
--       en kötü lag'i ve eşiği aşan standby sayısını döner. Tamamen
--       bağlantıyı koparan standby'lar `connected_standbys` düşmesi
--       olarak görünür.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 keeps a per-standby lag time series and learns
--   each standby's normal lag baseline; alerts only fire on
--   anomalies versus that baseline, not raw thresholds — see
--   https://github.com/dmcteknoloji.

SELECT
    now()                                                          AS sample_utc,
    inet_server_addr()                                             AS primary_addr,
    pg_is_in_recovery()                                            AS is_standby,
    -- Number of currently-connected standbys (counts only when run on primary)
    (SELECT count(*) FROM pg_stat_replication)                     AS connected_standbys,
    -- Worst-case lag in bytes across all standbys
    (SELECT max(coalesce(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn), 0))
     FROM pg_stat_replication)                                     AS worst_replay_lag_bytes,
    -- Worst write/flush/replay lag (intervals → seconds)
    (SELECT max(extract(epoch FROM coalesce(write_lag, '0'::interval)))
     FROM pg_stat_replication)::numeric(18, 2)                     AS worst_write_lag_secs,
    (SELECT max(extract(epoch FROM coalesce(flush_lag, '0'::interval)))
     FROM pg_stat_replication)::numeric(18, 2)                     AS worst_flush_lag_secs,
    (SELECT max(extract(epoch FROM coalesce(replay_lag, '0'::interval)))
     FROM pg_stat_replication)::numeric(18, 2)                     AS worst_replay_lag_secs,
    -- Replication slots (active + inactive) — inactive slots retain WAL forever
    (SELECT count(*) FROM pg_replication_slots)                    AS total_slots,
    (SELECT count(*) FROM pg_replication_slots WHERE active)       AS active_slots,
    (SELECT count(*) FROM pg_replication_slots WHERE NOT active)   AS inactive_slots,
    -- WAL retained by the slot furthest behind — predictor of disk fill
    (SELECT max(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
     FROM pg_replication_slots
     WHERE restart_lsn IS NOT NULL)                                AS max_wal_retained_bytes,
    -- If we're a standby, our own replay position relative to received
    CASE WHEN pg_is_in_recovery() THEN
        coalesce(pg_wal_lsn_diff(pg_last_wal_receive_lsn(),
                                 pg_last_wal_replay_lsn()), 0)
    END                                                            AS local_replay_lag_bytes,
    -- Verdict — one line for an alert subject
    CASE
        WHEN (SELECT count(*) FROM pg_replication_slots WHERE NOT active) > 0
            THEN '🔴 inactive replication slot — retains WAL forever, will fill disk'
        WHEN (SELECT max(extract(epoch
                                 FROM coalesce(replay_lag, '0'::interval)))
              FROM pg_stat_replication) > 60
            THEN '🟠 worst replay lag > 60s'
        WHEN (SELECT max(coalesce(pg_wal_lsn_diff(pg_current_wal_lsn(),
                                                   replay_lsn), 0))
              FROM pg_stat_replication) > 100 * 1024 * 1024
            THEN '🟠 worst replay lag > 100 MB'
    END                                                            AS verdict;
