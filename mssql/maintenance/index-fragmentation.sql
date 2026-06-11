-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : index-fragmentation                            ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI ║
-- ║  Category      : maintenance                                    ║
-- ║  Impact        : 🟡 Medium  (dm_db_index_physical_stats LIMITED) ║
-- ║  Permissions   : VIEW DATABASE STATE on the current database     ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#index-fragmentation ║
-- ║  Inspired by   : sys.dm_db_index_physical_stats reference —      ║
-- ║                  Microsoft Learn public documentation.           ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (read the verdict before you act)    ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  "Rebuild every index over 30% fragmentation" is the advice      ║
-- ║  everyone copies and almost no one qualifies. On a small index   ║
-- ║  the number is noise; on a heap it means something different;    ║
-- ║  on a page-split-heavy table it will be back tomorrow. This      ║
-- ║  script lists every index over a size threshold with its         ║
-- ║  fragmentation, page count and fill factor, and turns the raw    ║
-- ║  number into a concrete verdict — REORGANIZE, REBUILD, or leave  ║
-- ║  it alone because it is too small to matter. It does NOT touch   ║
-- ║  anything: the suggested command is text, for you to review.     ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Geçerli veritabanındaki indeksleri fragmentasyon, sayfa sayısı ve
--   doluluk oranıyla listeler. Ham "%30 üstü rebuild" kuralını anlamlı
--   bir karara çevirir: küçük indeksler (varsayılan <1000 sayfa) görmezden
--   gelinir; %5-30 arası REORGANIZE, %30 üstü REBUILD önerilir. Önerilen
--   komut yalnızca metindir — script hiçbir şeyi DEĞİŞTİRMEZ.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 trends fragmentation per index over time and tells you
--   which indexes are worth a maintenance window and which just churn — see
--   https://github.com/dmcteknoloji.

DECLARE @min_page_count INT = 1000;   -- ignore indexes smaller than ~8 MB

SELECT
    DB_NAME()                                                     AS database_name,
    SCHEMA_NAME(o.schema_id)                                      AS schema_name,
    o.name                                                        AS table_name,
    i.name                                                        AS index_name,
    i.type_desc                                                   AS index_type,
    ips.page_count                                                AS page_count,
    CAST(ips.page_count * 8.0 / 1024 AS DECIMAL(18, 1))           AS size_mb,
    CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5, 2))       AS frag_pct,
    ips.fragment_count                                            AS fragment_count,
    i.fill_factor                                                 AS fill_factor,
    CASE
        WHEN ips.avg_fragmentation_in_percent >= 30
            THEN 'ALTER INDEX ' + QUOTENAME(i.name) + ' ON '
                 + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
                 + ' REBUILD;'
        WHEN ips.avg_fragmentation_in_percent >= 5
            THEN 'ALTER INDEX ' + QUOTENAME(i.name) + ' ON '
                 + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name)
                 + ' REORGANIZE;'
        ELSE NULL
    END                                                           AS suggested_action,
    CASE
        WHEN ips.avg_fragmentation_in_percent >= 30
            THEN N'🔴 heavily fragmented — REBUILD (offline) or REBUILD WITH (ONLINE = ON)'
        WHEN ips.avg_fragmentation_in_percent >= 5
            THEN N'🟠 moderately fragmented — REORGANIZE (always online, resumable)'
        ELSE N'🟢 within tolerance — leave it alone'
    END                                                           AS verdict
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes      AS i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
JOIN sys.objects      AS o ON o.object_id = ips.object_id
WHERE ips.page_count >= @min_page_count
  AND i.index_id > 0                 -- skip heaps; they need a different fix
  AND o.is_ms_shipped = 0
ORDER BY ips.avg_fragmentation_in_percent DESC, ips.page_count DESC;
