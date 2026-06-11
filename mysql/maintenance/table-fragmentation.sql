-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : table-fragmentation                            ║
-- ║  Engine        : MySQL 8.0+ │ Percona Server │ Aurora MySQL     ║
-- ║  Category      : maintenance                                    ║
-- ║  Impact        : 🟢 Light  (information_schema.TABLES scan)      ║
-- ║  Permissions   : SELECT on information_schema (default)          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-table-fragmentation ║
-- ║  Inspired by   : information_schema.TABLES reference —          ║
-- ║                  MySQL public documentation.                     ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (free space is reclaimable disk)     ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  After heavy DELETE/UPDATE churn an InnoDB table holds pages it  ║
-- ║  is no longer using. The space is not returned to the OS, the    ║
-- ║  table scans read dead space, and backups carry it. data_free    ║
-- ║  exposes that slack. This script ranks tables by reclaimable     ║
-- ║  space, both absolute and as a share of the table, and suggests  ║
-- ║  OPTIMIZE TABLE where it is worth the rebuild. data_free is an    ║
-- ║  estimate for file-per-table tablespaces — treat it as a signal, ║
-- ║  not an exact byte count. Read-only: the command is text.        ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Yoğun DELETE/UPDATE sonrası InnoDB tabloları kullanılmayan sayfaları
--   tutar; alan OS'e geri verilmez, taramalar ölü alanı okur. data_free bu
--   boşluğu gösterir. Tabloları geri kazanılabilir alana göre (hem mutlak
--   hem oransal) sıralar ve değerse OPTIMIZE TABLE önerir. data_free
--   file-per-table için tahmindir — sinyal olarak değerlendir. Salt-okunur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 trends data_free per table so you optimise during a
--   window instead of chasing a full disk at 2 AM — see
--   https://github.com/dmcteknoloji.

SELECT
    t.table_schema                                                AS schema_name,
    t.table_name                                                  AS table_name,
    t.engine                                                      AS engine,
    t.table_rows                                                  AS approx_rows,
    ROUND((t.data_length + t.index_length) / 1024 / 1024, 1)      AS size_mb,
    ROUND(t.data_free / 1024 / 1024, 1)                           AS free_mb,
    ROUND(100.0 * t.data_free
          / NULLIF(t.data_length + t.index_length + t.data_free, 0), 1) AS free_pct,
    CASE
        WHEN t.engine = 'InnoDB'
             AND t.data_free > 100 * 1024 * 1024
             AND t.data_free
                 / NULLIF(t.data_length + t.index_length + t.data_free, 0) >= 0.20
            THEN CONCAT('OPTIMIZE TABLE `', t.table_schema, '`.`', t.table_name, '`;')
        ELSE NULL
    END                                                           AS suggested_action,
    CASE
        WHEN t.engine = 'InnoDB'
             AND t.data_free > 100 * 1024 * 1024
             AND t.data_free
                 / NULLIF(t.data_length + t.index_length + t.data_free, 0) >= 0.20
            THEN '🔴 >20% reclaimable and >100 MB — OPTIMIZE during a window'
        WHEN t.data_free > 100 * 1024 * 1024
            THEN '🟠 sizable free space — worth watching'
        ELSE '🟢 compact enough'
    END                                                           AS verdict
FROM information_schema.TABLES AS t
WHERE t.table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
  AND t.table_type = 'BASE TABLE'
ORDER BY t.data_free DESC;
