-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : query-throughput-snapshot                       ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (global_status scan)                   ║
-- ║  Permissions   : SELECT on performance_schema.global_status      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-query-throughput-snapshot ║
-- ║  Inspired by   : MySQL Reference Manual — Server Status Variables║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: One row per call with cumulative + rate-since-startup MySQL
--       throughput. Counters in MySQL are STATUS variables, all
--       cumulative — sample twice and diff for instant rate, or
--       chart the slope from a periodic table dump.
--   TR: Çağrı başına tek satır: kümülatif + başlangıçtan beri
--       ortalama MySQL throughput'u. Sayaçlar STATUS değişkenleri,
--       hepsi kümülatif — anlık oran için iki örnek alıp diff'le,
--       ya da periyodik tablo dump'ından eğimi grafik haline getir.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 collects this every 60 seconds, computes per-
--   second rates, and baselines per workload pattern — see
--   https://github.com/dmcteknoloji.

SELECT
    NOW(6)                                                              AS sample_utc,
    @@hostname                                                          AS hostname,
    @@server_id                                                         AS server_id,
    -- Server uptime — denominator for rate calculations
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Uptime')                                    AS uptime_secs,
    -- Throughput counters (cumulative)
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Questions')                                 AS questions_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Queries')                                   AS queries_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_select')                                AS com_select_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_insert')                                AS com_insert_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_update')                                AS com_update_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_delete')                                AS com_delete_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_commit')                                AS com_commit_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Com_rollback')                              AS com_rollback_cum,
    -- Health signals (cumulative)
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Slow_queries')                              AS slow_queries_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Aborted_clients')                           AS aborted_clients_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Aborted_connects')                          AS aborted_connects_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Connection_errors_max_connections')         AS conn_err_max_cum,
    -- Average rates (cumulative / uptime)
    ROUND(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Questions') * 1.0
        / NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status
                  WHERE VARIABLE_NAME = 'Uptime'), 0),
        2)                                                              AS questions_per_sec_avg,
    ROUND(
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Slow_queries') * 1.0
        / NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status
                  WHERE VARIABLE_NAME = 'Uptime'), 0),
        4)                                                              AS slow_queries_per_sec_avg,
    -- Sort/temp signals — high values point at queries that need indexes
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Created_tmp_disk_tables')                   AS tmp_disk_tables_cum,
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Sort_merge_passes')                         AS sort_merge_passes_cum;
