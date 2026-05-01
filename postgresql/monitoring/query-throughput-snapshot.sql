-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : query-throughput-snapshot                       ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (catalog/stat views only)              ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_stat_database   ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-query-throughput-snapshot ║
-- ║  Inspired by   : pg_stat_database / pg_stat_bgwriter — official  ║
-- ║                  PostgreSQL monitoring documentation.             ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Postgres exposes throughput as cumulative counters on
--       pg_stat_database. Sample twice and diff for instantaneous
--       rate, or run this every minute and graph the slope. The
--       snapshot also returns rate-since-stats-reset (cumulative /
--       elapsed) which is good enough for steady workloads.
--   TR: Postgres throughput'unu pg_stat_database üzerinde kümülatif
--       sayaç olarak verir. Anlık oran için iki örnek alıp diff'le,
--       ya da dakikada bir çalıştır ve eğimi grafik haline getir.
--       Snapshot ayrıca stats-reset-tabanlı oran (kümülatif /
--       geçen süre) verir — düz iş yükleri için yeterlidir.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 ingests this every 60 seconds across every
--   PostgreSQL instance, computes per-second rates, and baselines
--   per-database — see https://github.com/dmcteknoloji.

WITH stats AS (
    SELECT
        sum(xact_commit)                  AS commits_cum,
        sum(xact_rollback)                AS rollbacks_cum,
        sum(blks_hit)                     AS blks_hit_cum,
        sum(blks_read)                    AS blks_read_cum,
        sum(tup_returned)                 AS tup_returned_cum,
        sum(tup_fetched)                  AS tup_fetched_cum,
        sum(tup_inserted)                 AS tup_inserted_cum,
        sum(tup_updated)                  AS tup_updated_cum,
        sum(tup_deleted)                  AS tup_deleted_cum,
        sum(deadlocks)                    AS deadlocks_cum,
        sum(temp_files)                   AS temp_files_cum,
        sum(temp_bytes)                   AS temp_bytes_cum,
        min(stats_reset)                  AS stats_reset_at
    FROM pg_stat_database
    WHERE datname IS NOT NULL
)
SELECT
    now()                                                   AS sample_utc,
    inet_server_addr()                                      AS server_addr,
    s.stats_reset_at                                        AS stats_reset_at,
    extract(epoch FROM (now() - s.stats_reset_at))::bigint  AS stats_window_secs,
    -- Cumulative — diff client-side for instant rate
    s.commits_cum,
    s.rollbacks_cum,
    s.blks_hit_cum,
    s.blks_read_cum,
    s.tup_returned_cum,
    s.tup_fetched_cum,
    s.tup_inserted_cum,
    s.tup_updated_cum,
    s.tup_deleted_cum,
    s.deadlocks_cum,
    s.temp_files_cum,
    s.temp_bytes_cum,
    -- Average rates since stats reset (rough but usable for baseline)
    round(s.commits_cum * 1.0
          / nullif(extract(epoch FROM (now() - s.stats_reset_at))::numeric, 0), 2)
                                                            AS commits_per_sec_avg,
    round(s.rollbacks_cum * 1.0
          / nullif(extract(epoch FROM (now() - s.stats_reset_at))::numeric, 0), 2)
                                                            AS rollbacks_per_sec_avg,
    -- Cache hit ratio — should sit above 99% for OLTP workloads.
    round(100.0 * s.blks_hit_cum
          / nullif(s.blks_hit_cum + s.blks_read_cum, 0), 2)
                                                            AS cache_hit_pct,
    -- Rollback ratio — high values indicate application-level retry storms.
    round(100.0 * s.rollbacks_cum
          / nullif(s.commits_cum + s.rollbacks_cum, 0), 2)
                                                            AS rollback_pct,
    -- BG writer contribution (cumulative across instance lifetime)
    bg.buffers_checkpoint                                   AS buffers_checkpoint_cum,
    bg.buffers_clean                                        AS buffers_clean_cum,
    bg.buffers_backend                                      AS buffers_backend_cum,
    bg.maxwritten_clean                                     AS bg_maxwritten_clean_cum,
    -- Live workload right now
    (SELECT count(*) FROM pg_stat_activity
     WHERE pid <> pg_backend_pid())                         AS connections_now,
    (SELECT count(*) FROM pg_stat_activity
     WHERE state = 'active' AND pid <> pg_backend_pid())    AS connections_active_now
FROM stats              AS s
CROSS JOIN pg_stat_bgwriter AS bg;
