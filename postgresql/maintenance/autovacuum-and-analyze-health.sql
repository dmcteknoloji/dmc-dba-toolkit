-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : autovacuum-and-analyze-health                  ║
-- ║  Engine        : PostgreSQL 12+ │ Aurora PG │ Cloud SQL PG      ║
-- ║  Category      : maintenance                                    ║
-- ║  Impact        : 🟢 Light  (pg_stat_user_tables scan)            ║
-- ║  Permissions   : SELECT on pg_stat_user_tables (default role)    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-autovacuum-and-analyze-health ║
-- ║  Inspired by   : pg_stat_user_tables reference —                ║
-- ║                  PostgreSQL public documentation.                ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (dead tuples are bloat in waiting)   ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Autovacuum is not "set and forget". On a high-churn table the   ║
-- ║  default thresholds let dead tuples pile up between runs, the    ║
-- ║  table bloats, and the planner works off stale row counts. The   ║
-- ║  signals are all in pg_stat_user_tables but spread across a      ║
-- ║  dozen columns nobody reads in an incident. This script collapses ║
-- ║  them into one row per table: dead-tuple ratio, rows changed     ║
-- ║  since the last analyze, when autovacuum/autoanalyze last ran,   ║
-- ║  and a verdict on which tables are falling behind. Read-only.    ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Her kullanıcı tablosu için ölü-tuple oranını, son analyze'dan bu yana
--   değişen satır sayısını ve autovacuum/autoanalyze'ın en son ne zaman
--   çalıştığını tek satırda toplar. Yüksek ölü-tuple oranı = yaklaşan bloat
--   + bayat planlar. %20'den fazla ölü tuple olan tablolar VACUUM/ANALYZE
--   adayı olarak işaretlenir. Salt-okunur; hiçbir şey çalıştırmaz.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 baselines dead-tuple growth per table and flags the ones
--   autovacuum can't keep up with before they bloat — see
--   https://github.com/dmcteknoloji.

SELECT
    schemaname                                                    AS schema_name,
    relname                                                       AS table_name,
    n_live_tup                                                    AS live_tuples,
    n_dead_tup                                                    AS dead_tuples,
    round(100.0 * n_dead_tup
          / nullif(n_live_tup + n_dead_tup, 0), 1)                AS dead_pct,
    n_mod_since_analyze                                           AS rows_changed_since_analyze,
    last_autovacuum                                               AS last_autovacuum,
    last_vacuum                                                   AS last_manual_vacuum,
    last_autoanalyze                                              AS last_autoanalyze,
    last_analyze                                                  AS last_manual_analyze,
    autovacuum_count                                              AS autovacuum_runs,
    autoanalyze_count                                             AS autoanalyze_runs,
    CASE
        WHEN n_live_tup + n_dead_tup >= 1000
             AND n_dead_tup * 1.0 / nullif(n_live_tup + n_dead_tup, 0) >= 0.20
            THEN '🔴 >20% dead tuples — VACUUM (and review autovacuum_vacuum_scale_factor)'
        WHEN n_mod_since_analyze >= 10000
             AND n_mod_since_analyze >= n_live_tup * 0.10
            THEN '🟠 many rows changed since last analyze — ANALYZE for fresh estimates'
        WHEN last_autovacuum IS NULL AND last_vacuum IS NULL AND n_dead_tup > 0
            THEN '🟡 never vacuumed yet — watch as it grows'
        ELSE '🟢 autovacuum keeping up'
    END                                                           AS verdict
FROM pg_stat_user_tables
ORDER BY
    n_dead_tup * 1.0 / nullif(n_live_tup + n_dead_tup, 0) DESC NULLS LAST,
    n_dead_tup DESC;
