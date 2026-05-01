-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : checkpoint-bgwriter-efficiency                  ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (pg_stat_bgwriter scan)                ║
-- ║  Permissions   : pg_read_all_stats; SELECT on pg_stat_bgwriter   ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-checkpoint-bgwriter-efficiency ║
-- ║  Inspired by   : PostgreSQL official docs on checkpointer +      ║
-- ║                  bgwriter; the "tune for fewer requested          ║
-- ║                  checkpoints" guidance is widely shared in the   ║
-- ║                  PG community (Bruce Momjian talks, pganalyze    ║
-- ║                  blog) — technique credited.                      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (writeback efficiency analysis + recommendations) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Postgres'in dirty page yazma mekanizmalarının verimliliğini
--   raporlar: checkpoint × bgwriter × backend yazma oranları,
--   timed vs requested checkpoint dağılımı, checkpoint başına
--   ortalama write/sync süresi. Sağlıklı cluster'da yazıların
--   çoğu checkpoint zamanında yapılır; backend tarafından yapılan
--   yazımlar ise (buffers_backend) %5 altında kalmalıdır. Yüksek
--   buffers_backend = checkpointer geride kalıyor → daha sık
--   checkpoint için tune et.
--
-- Why this exists:
--   pg_stat_bgwriter is the canonical view of "how is Postgres
--   actually flushing dirty pages?" — and it's nuanced. Three
--   writers compete: the checkpointer (timed bursts), the bgwriter
--   (continuous trickle), and user backends (the path nobody wants
--   to take). The ratios between them tell you whether your
--   checkpoint_timeout / max_wal_size are tuned, whether your IO
--   subsystem is healthy, and whether user queries are pausing to
--   write dirty pages themselves.

WITH bg AS (
    SELECT * FROM pg_stat_bgwriter
)
SELECT
    now()                                                         AS sample_utc,
    'CHECKPOINT_VS_BGWRITER'                                      AS section,

    -- Raw cumulative counts
    bg.checkpoints_timed                                          AS checkpoints_timed,
    bg.checkpoints_req                                            AS checkpoints_requested,
    bg.checkpoints_timed + bg.checkpoints_req                     AS checkpoints_total,

    -- Ratio of timed to total — should be > 90% on a healthy
    -- workload. Low values mean checkpoint_timeout / max_wal_size are
    -- not aligned with the workload — checkpoints fire because
    -- max_wal_size is hit before the timer elapses.
    round(100.0 * bg.checkpoints_timed
          / nullif(bg.checkpoints_timed + bg.checkpoints_req, 0), 2)
                                                                  AS pct_checkpoints_timed,

    -- Average time per checkpoint (write + sync phases)
    round(bg.checkpoint_write_time::numeric / 1000
          / nullif(bg.checkpoints_timed + bg.checkpoints_req, 0), 2)
                                                                  AS avg_checkpoint_write_secs,
    round(bg.checkpoint_sync_time::numeric / 1000
          / nullif(bg.checkpoints_timed + bg.checkpoints_req, 0), 2)
                                                                  AS avg_checkpoint_sync_secs,

    -- Buffer accounting — who actually wrote the dirty pages?
    bg.buffers_checkpoint                                         AS buffers_via_checkpoint,
    bg.buffers_clean                                              AS buffers_via_bgwriter,
    bg.buffers_backend                                            AS buffers_via_backend,
    bg.buffers_alloc                                              AS buffers_allocated,

    -- The headline ratio. Healthy: checkpoint dominant.
    round(100.0 * bg.buffers_checkpoint
          / nullif(bg.buffers_checkpoint + bg.buffers_clean
                   + bg.buffers_backend, 0), 2)
                                                                  AS pct_writes_checkpoint,
    round(100.0 * bg.buffers_clean
          / nullif(bg.buffers_checkpoint + bg.buffers_clean
                   + bg.buffers_backend, 0), 2)
                                                                  AS pct_writes_bgwriter,
    round(100.0 * bg.buffers_backend
          / nullif(bg.buffers_checkpoint + bg.buffers_clean
                   + bg.buffers_backend, 0), 2)
                                                                  AS pct_writes_backend,

    -- The backend fsync counter. > 0 is bad: backends were forced to
    -- fsync because the checkpointer's queue was full.
    bg.buffers_backend_fsync                                      AS backend_fsyncs_cum,

    -- bgwriter saturation: maxwritten_clean increments when the bgwriter
    -- hit its dirty-page-per-cycle limit. Persistent non-zero growth
    -- means bgwriter_lru_maxpages should rise.
    bg.maxwritten_clean                                           AS bgwriter_max_writes_hit,

    -- Current settings (so the alert subject can include them)
    current_setting('checkpoint_timeout')                         AS checkpoint_timeout,
    current_setting('checkpoint_completion_target')               AS checkpoint_completion_target,
    current_setting('max_wal_size')                               AS max_wal_size,
    current_setting('bgwriter_lru_maxpages')                      AS bgwriter_lru_maxpages,
    current_setting('bgwriter_delay')                             AS bgwriter_delay,

    -- Verdict — concrete tuning recommendations
    CASE
        WHEN bg.buffers_backend_fsync > 0
            THEN '🔴 backend_fsync > 0 — IO stack stressed enough to bypass checkpointer; investigate disk latency'
        WHEN round(100.0 * bg.buffers_backend
                   / nullif(bg.buffers_checkpoint + bg.buffers_clean
                            + bg.buffers_backend, 0), 2) > 20
            THEN '🔴 backends writing > 20% of dirty pages — raise checkpoint_completion_target or shorten checkpoint_timeout'
        WHEN round(100.0 * bg.checkpoints_req
                   / nullif(bg.checkpoints_timed + bg.checkpoints_req, 0), 2) > 30
            THEN '🟠 > 30% of checkpoints are requested (max_wal_size hits) — raise max_wal_size or shorten checkpoint_timeout'
        WHEN bg.maxwritten_clean > bg.checkpoints_total
            THEN '🟠 bgwriter saturating frequently — raise bgwriter_lru_maxpages'
        ELSE '🟢 checkpoint vs bgwriter balance looks healthy'
    END                                                           AS verdict,
    bg.stats_reset                                                AS stats_reset_at
FROM bg;
