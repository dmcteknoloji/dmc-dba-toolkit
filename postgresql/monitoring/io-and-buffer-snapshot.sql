-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : io-and-buffer-snapshot                          ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║                  (richer output on PG 16+ via pg_stat_io)        ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (catalog views; pg_stat_io on PG 16+)  ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_stat_database / ║
-- ║                  pg_stat_io / pg_stat_bgwriter                   ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-io-and-buffer-snapshot ║
-- ║  Inspired by   : pg_stat_io documentation (PG 16 release notes), ║
-- ║                  pg_stat_database / pg_stat_bgwriter references. ║
-- ║                  Lukas Fittl's pganalyze posts informed the       ║
-- ║                  derived metrics; technique credited.             ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (multi-view IO accounting + version-aware fallback) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   PG 16+ için pg_stat_io üzerinden backend tipi × IO context
--   kırılımı verir (regular / vacuum / bulk-read / bulk-write), 13-15
--   için pg_stat_database + pg_stat_bgwriter fallback'ı çalışır.
--   Buffer pool hit oranı, fiziksel okuma sayacı, BG writer'in ne
--   kadarını hangi yolla yazdığı (checkpoint vs background vs backend)
--   tek satırda. Backend tarafından yazılan oran (buffers_backend /
--   total) yüksekse — "checkpoint geride kalıyor" demektir.
--
-- Why this exists:
--   PG 16 introduced pg_stat_io, which is the modern, structured
--   replacement for the historical pieced-together view of IO. This
--   script uses it where available and falls back to pg_stat_database
--   + pg_stat_bgwriter on older versions. The output is shaped to fit
--   the same time-series target table on either side of the upgrade.

-- ── 1. ALWAYS-AVAILABLE HEADLINE (PG 13+) ──────────────────────────
SELECT
    now()                                                          AS sample_utc,
    inet_server_addr()                                             AS server_addr,
    'HEADLINE'                                                     AS section,
    -- Aggregate cache hit ratio across all DBs
    (SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 2)
     FROM pg_stat_database)                                        AS cache_hit_pct,
    (SELECT sum(blks_hit) FROM pg_stat_database)                   AS blks_hit_cum,
    (SELECT sum(blks_read) FROM pg_stat_database)                  AS blks_read_cum,
    -- Background writer accounting
    bg.checkpoints_timed                                           AS checkpoints_timed,
    bg.checkpoints_req                                             AS checkpoints_requested,
    bg.checkpoint_write_time                                       AS checkpoint_write_ms,
    bg.checkpoint_sync_time                                        AS checkpoint_sync_ms,
    bg.buffers_checkpoint                                          AS buffers_via_checkpoint,
    bg.buffers_clean                                               AS buffers_via_bgwriter,
    bg.buffers_backend                                             AS buffers_via_backend,
    bg.buffers_backend_fsync                                       AS backend_fsyncs,
    bg.maxwritten_clean                                            AS bgwriter_stops,
    -- Backend-write ratio: high values mean checkpoint can't keep up
    -- so user backends are paying the cost. Healthy clusters keep this
    -- ratio < 5% — anything above is a tuning signal.
    round(100.0 * bg.buffers_backend
          / nullif(bg.buffers_checkpoint + bg.buffers_clean
                   + bg.buffers_backend, 0), 2)                    AS backend_write_pct,
    -- Verdict
    CASE
        WHEN round(100.0 * bg.buffers_backend
                   / nullif(bg.buffers_checkpoint + bg.buffers_clean
                            + bg.buffers_backend, 0), 2) > 20
            THEN '🔴 backend_write_pct > 20% — checkpoints lag, tune for more frequent ones'
        WHEN bg.buffers_backend_fsync > 0
            THEN '🟠 backend fsync != 0 — IO subsystem stressed enough to force backend syncs'
        WHEN bg.checkpoints_req > bg.checkpoints_timed
            THEN '🟠 requested > timed checkpoints — workload outpaces checkpoint_timeout'
    END                                                            AS verdict
FROM pg_stat_bgwriter AS bg;

-- ── 2. PG 16+ pg_stat_io — backend × IO context breakdown ────────
-- Returns nothing on PG 13-15 because the view doesn't exist there;
-- the headline section above is sufficient on those versions.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_class
               WHERE relname = 'pg_stat_io' AND relkind = 'v') THEN
        RAISE NOTICE 'pg_stat_io is available — second result set follows';
    ELSE
        RAISE NOTICE 'pg_stat_io not available on this version — only the headline section returns';
    END IF;
END$$;

-- The query below errors out on < PG 16. Wrap in a guard if you want
-- a single composable script.
SELECT
    'PG_STAT_IO'                                                   AS section,
    backend_type,
    object,
    context,
    reads,
    writes,
    extends,
    -- Average wait per IO if the version reports it
    round(read_time::numeric / nullif(reads, 0), 3)                AS avg_read_ms_per_io,
    round(write_time::numeric / nullif(writes, 0), 3)              AS avg_write_ms_per_io,
    -- Hits / evictions / fsync — only populated for some contexts
    hits,
    evictions,
    reuses,
    fsyncs,
    stats_reset
FROM pg_stat_io
WHERE reads + writes + extends > 0
ORDER BY reads + writes DESC;
