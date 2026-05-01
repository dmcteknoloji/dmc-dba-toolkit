-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : wait-events-summary                             ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (single pg_stat_activity scan)         ║
-- ║  Permissions   : pg_read_all_stats (recommended) or superuser    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-wait-events-summary║
-- ║  Inspired by   : PostgreSQL official wait event documentation     ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-10-22                                      ║
-- ║  Level         : 🦅 Expert   (output requires deep DMV / internals knowledge)      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Aktif backend'leri wait event'e göre gruplar — anlık snapshot. SQL
--   Server'dan farkı: pg_stat_activity kümülatif değil, sadece şu anı
--   yansıtır. Trend için periyodik örneklemeli toplama gerekir.
--   state_age ile sıkışmış idle-in-transaction'ı yakalar.
--
-- Snapshot of currently active backends grouped by their wait event,
-- with state and duration. Unlike the equivalent SQL Server script
-- (which uses cumulative DMV counters), Postgres exposes wait events as
-- a *current* sample — pg_stat_activity reflects this instant only.
--
-- For trend analysis, sample this query at a regular interval (e.g.
-- every second for 60s) and aggregate externally. A single snapshot is
-- enough to identify current contention.
--
-- Wait event categories (wait_event_type) are documented in the official
-- PostgreSQL manual under "Monitoring Database Activity".

SELECT
    coalesce(wait_event_type, 'CPU/Running')                     AS wait_event_type,
    coalesce(wait_event, '<no wait>')                            AS wait_event,
    state,
    count(*)                                                     AS sessions,
    -- Duration in this state — useful to spot stuck IDLE-IN-TRANSACTION
    -- and long-running queries at a glance.
    round(extract(epoch FROM (now() - state_change))::numeric, 2) AS state_age_seconds_max,
    string_agg(DISTINCT datname, ', ')                           AS databases,
    string_agg(DISTINCT usename, ', ')                           AS users,
    string_agg(DISTINCT application_name, ', ')                  AS applications
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
  AND backend_type = 'client backend'
GROUP BY
    coalesce(wait_event_type, 'CPU/Running'),
    coalesce(wait_event, '<no wait>'),
    state,
    state_change
ORDER BY sessions DESC, state_age_seconds_max DESC;
