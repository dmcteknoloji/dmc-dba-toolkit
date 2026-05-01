-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : missing-indexes                                 ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (DMV scan, no DDL produced)            ║
-- ║  Permissions   : VIEW SERVER STATE, VIEW DATABASE STATE          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#missing-indexes      ║
-- ║  Inspired by   : sys.dm_db_missing_index_* family — Microsoft    ║
-- ║                  Learn public reference. Code original.          ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-03-24                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Optimizer'ın istediği eksik indeksleri user_seeks * avg_total_user_cost
--   * (avg_user_impact / 100) formülüyle skorlar. DMV instance restart'ta
--   veya plan cache flush'ta sıfırlanır — sıralamayı "cache son ısındığından
--   beri" olarak oku. CREATE INDEX üretmez; önce incele, sonra tasarla.
--
-- Returns the missing indexes the optimiser has been wishing for, ranked
-- by an "impact score" derived from user_seeks * (avg_total_user_cost
-- * (avg_user_impact / 100.0)) — the canonical formula from Microsoft's
-- own documentation.
--
-- The DMV resets on instance restart and on plan cache flushes, so treat
-- the rankings as "since the cache last warmed up". A high impact score
-- across many seeks is a strong candidate; a 99% impact across two seeks
-- is not. Always inspect the proposed index for overlap with existing
-- indexes before creating it.
--
-- This script intentionally does NOT generate CREATE INDEX statements —
-- inspect first, design second.

DECLARE @top_n INT = 25;

SELECT TOP (@top_n)
    ROW_NUMBER() OVER (ORDER BY
        migs.user_seeks
        * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) DESC)                 AS [rank],
    DB_NAME(mid.database_id)                                   AS database_name,
    OBJECT_SCHEMA_NAME(mid.[object_id], mid.database_id)       AS schema_name,
    OBJECT_NAME(mid.[object_id], mid.database_id)              AS table_name,
    CAST(migs.user_seeks AS BIGINT)                            AS user_seeks,
    CAST(migs.user_scans AS BIGINT)                            AS user_scans,
    CAST(migs.avg_total_user_cost AS DECIMAL(18, 2))           AS avg_total_user_cost,
    CAST(migs.avg_user_impact AS DECIMAL(5, 2))                AS avg_user_impact_pct,
    CAST(
        migs.user_seeks
        * migs.avg_total_user_cost
        * (migs.avg_user_impact / 100.0) AS DECIMAL(18, 2)
    )                                                          AS impact_score,
    migs.last_user_seek                                        AS last_user_seek,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig
    ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details AS mid
    ON mid.index_handle = mig.index_handle
WHERE mid.database_id > 4
ORDER BY impact_score DESC;
