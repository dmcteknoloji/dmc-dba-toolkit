-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : statistics-health                              ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI ║
-- ║  Category      : maintenance                                    ║
-- ║  Impact        : 🟢 Light  (catalog + dm_db_stats_properties)    ║
-- ║  Permissions   : VIEW DATABASE STATE on the current database     ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#statistics-health   ║
-- ║  Inspired by   : sys.dm_db_stats_properties reference —          ║
-- ║                  Microsoft Learn public documentation.           ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (stale stats = bad plans)            ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Index fragmentation gets all the attention; stale statistics    ║
-- ║  quietly cause more pain. The optimiser builds plans from row     ║
-- ║  estimates, and those estimates come from statistics. Let them    ║
-- ║  drift and you get the classic "it was fast yesterday" plan       ║
-- ║  regression with no schema change to blame. This script lists     ║
-- ║  statistics by how stale they are — rows modified since the last  ║
-- ║  update versus table size — and flags the ones worth a manual     ║
-- ║  UPDATE STATISTICS. Read-only: the suggested command is text.     ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   İstatistikleri bayatlık derecesine göre listeler: son güncellemeden bu
--   yana değişen satır sayısı, tablo büyüklüğüne oranı ve son güncelleme
--   zamanı. Bayat istatistik = kötü tahmin = kötü plan ("dün hızlıydı"
--   regresyonu). %20'den fazla satır değiştiyse UPDATE STATISTICS önerilir.
--   Önerilen komut metindir — script hiçbir şeyi DEĞİŞTİRMEZ.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 watches modification counters per object and alerts before
--   a stale-stats plan regression hits production — see
--   https://github.com/dmcteknoloji.

SELECT
    DB_NAME()                                                     AS database_name,
    SCHEMA_NAME(o.schema_id)                                      AS schema_name,
    o.name                                                        AS table_name,
    s.name                                                        AS stats_name,
    sp.last_updated                                               AS last_updated,
    DATEDIFF(DAY, sp.last_updated, SYSUTCDATETIME())              AS days_since_update,
    sp.rows                                                       AS table_rows,
    sp.rows_sampled                                               AS rows_sampled,
    sp.modification_counter                                       AS rows_modified,
    CAST(100.0 * sp.modification_counter
         / NULLIF(sp.rows, 0) AS DECIMAL(6, 2))                   AS pct_modified,
    CASE
        WHEN sp.rows >= 1000
             AND sp.modification_counter * 1.0 / NULLIF(sp.rows, 0) >= 0.20
            THEN 'UPDATE STATISTICS '
                 + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
                 + ' ' + QUOTENAME(s.name) + ' WITH FULLSCAN;'
        ELSE NULL
    END                                                           AS suggested_action,
    CASE
        WHEN sp.last_updated IS NULL
            THEN N'🟠 never updated — no histogram, estimates are guesses'
        WHEN sp.rows >= 1000
             AND sp.modification_counter * 1.0 / NULLIF(sp.rows, 0) >= 0.20
            THEN N'🔴 >20% of rows changed since last update — refresh statistics'
        WHEN sp.modification_counter > 0
            THEN N'🟡 some drift — fine unless you see estimate skew'
        ELSE N'🟢 fresh'
    END                                                           AS verdict
FROM sys.stats                                                    AS s
JOIN sys.objects                                                  AS o ON o.object_id = s.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id)   AS sp
WHERE o.is_ms_shipped = 0
  AND o.type = 'U'                  -- user tables only
ORDER BY
    CASE WHEN sp.rows >= 1000 THEN sp.modification_counter * 1.0 / NULLIF(sp.rows, 0) END DESC,
    sp.modification_counter DESC;
