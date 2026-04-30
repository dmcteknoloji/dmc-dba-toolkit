-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : health-snapshot                                 ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (designed for periodic execution)      ║
-- ║  Permissions   : pg_read_all_stats; standard SELECT on catalogs  ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-health-snapshot   ║
-- ║  Inspired by   : pg_stat_database, pg_stat_bgwriter — official   ║
-- ║                  PostgreSQL monitoring documentation.             ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-30                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: A timestamped snapshot suitable for cron + a target table.
--       Returns the headline metrics in a single row: connections,
--       transaction throughput (cumulative), cache hit ratio, biggest
--       idle-in-transaction, replication lag (if standby), and the
--       cluster's current write rate proxy.
--   TR: Cron + hedef tablo için tasarlanmış zaman damgalı snapshot.
--       Tek satırda manşet metrikleri döner: bağlantılar, transaction
--       throughput (kümülatif), cache hit oranı, en büyük idle-in-
--       transaction, replication lag (standby ise) ve cluster'ın
--       anlık yazma oranı yaklaşığı.
--
-- Beyond this script / Bunun ötesinde:
--   For continuous, multi-instance monitoring with alerting,
--   persistence, dashboards, and AI-assisted findings, see
--   DMC's Sentinel DB 360 — https://github.com/dmcteknoloji

SELECT
    now()                                                            AS sample_utc,
    inet_server_addr()                                               AS server_addr,
    current_database()                                               AS database_name,
    -- Connections
    (SELECT count(*) FROM pg_stat_activity WHERE pid <> pg_backend_pid())
                                                                     AS conn_total,
    (SELECT count(*) FROM pg_stat_activity
     WHERE state = 'active' AND pid <> pg_backend_pid())             AS conn_active,
    (SELECT count(*) FROM pg_stat_activity
     WHERE state = 'idle in transaction' AND pid <> pg_backend_pid())
                                                                     AS conn_idle_in_xact,
    current_setting('max_connections')::int                          AS max_connections,
    -- Transactions (cumulative since stats reset; diff externally for rate)
    (SELECT sum(xact_commit) FROM pg_stat_database)                  AS xact_commit_cumulative,
    (SELECT sum(xact_rollback) FROM pg_stat_database)                AS xact_rollback_cumulative,
    -- Cache hit ratio across the cluster
    (SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 2)
     FROM pg_stat_database)                                          AS cache_hit_pct,
    (SELECT sum(blks_hit + blks_read) FROM pg_stat_database)         AS total_block_reads_cumulative,
    -- Oldest running transaction
    (SELECT round(extract(epoch FROM (now() - min(xact_start)))::numeric, 1)
     FROM pg_stat_activity
     WHERE state <> 'idle' AND xact_start IS NOT NULL
       AND pid <> pg_backend_pid())                                  AS oldest_xact_secs,
    -- Replication: lag in bytes if standby; for primary, returns NULL
    CASE
        WHEN pg_is_in_recovery() THEN
            pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())
        ELSE NULL
    END                                                              AS replay_lag_bytes,
    -- BG writer activity (cumulative — useful as a write rate proxy)
    (SELECT buffers_checkpoint + buffers_clean + buffers_backend
     FROM pg_stat_bgwriter)                                          AS bg_buffers_written_cumulative;
