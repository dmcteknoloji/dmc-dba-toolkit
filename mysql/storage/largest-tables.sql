-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : largest-tables                                  ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : storage                                         ║
-- ║  Impact        : 🟢 Light  (information_schema scan)              ║
-- ║  Permissions   : SELECT on information_schema.tables             ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-largest-tables ║
-- ║  Inspired by   : information_schema.tables — MySQL Reference Manual ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-01-29                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the largest tables by total on-disk size (data + index),
-- with a fragmentation hint via DATA_FREE.
--
-- Caveats from the official manual:
--   - For InnoDB, DATA_LENGTH and INDEX_LENGTH are estimates from the
--     storage engine, not exact byte counts.
--   - DATA_FREE is the size of the free space allocated to the table
--     but not used. Large values can indicate fragmentation, but for
--     InnoDB tables in shared tablespaces it includes shared pool
--     headroom and is less actionable.
--   - For accurate numbers, run ANALYZE TABLE first; it doesn't lock
--     the table for reads on InnoDB but it does briefly block writes.

SELECT
    ROW_NUMBER() OVER (ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC) AS `rank`,
    TABLE_SCHEMA                                                   AS schema_name,
    TABLE_NAME                                                     AS table_name,
    ENGINE                                                         AS engine,
    TABLE_ROWS                                                     AS row_count_estimate,
    ROUND(DATA_LENGTH  / 1024 / 1024, 2)                           AS data_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 2)                           AS index_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2)           AS total_mb,
    ROUND(DATA_FREE / 1024 / 1024, 2)                              AS data_free_mb,
    CASE
        WHEN DATA_LENGTH = 0 THEN 0
        ELSE ROUND(100.0 * DATA_FREE / DATA_LENGTH, 1)
    END                                                            AS data_free_pct,
    ROW_FORMAT                                                     AS row_format,
    CREATE_TIME,
    UPDATE_TIME
FROM information_schema.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_SCHEMA NOT IN ('mysql', 'information_schema',
                           'performance_schema', 'sys')
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC
LIMIT 25;
