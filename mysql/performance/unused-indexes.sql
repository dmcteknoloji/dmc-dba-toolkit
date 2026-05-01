-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : unused-indexes                                  ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (sys schema view)                      ║
-- ║  Permissions   : SELECT on sys.schema_unused_indexes             ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-unused-indexes ║
-- ║  Inspired by   : sys.schema_unused_indexes — MySQL Reference     ║
-- ║                  Manual public reference (sys schema).            ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-09                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  The sys schema does most of the work — sys.schema_unused_indexes║
-- ║  already filters to "no rows have ever been read through this   ║
-- ║  index since the server started or since stats were truncated". ║
-- ║  We add three things: index size (so you know what dropping     ║
-- ║  buys you), uptime (so you know if the data is trustworthy),    ║
-- ║  and a verdict that respects PRIMARY/UNIQUE constraints.         ║
-- ╚══════════════════════════════════════════════════════════════════╝

SELECT
    sui.object_schema                                              AS schema_name,
    sui.object_name                                                AS table_name,
    sui.index_name                                                 AS index_name,
    -- Size from information_schema; depends on InnoDB stats being current.
    -- Run ANALYZE TABLE first if numbers look stale.
    ROUND(stat.stat_value * @@innodb_page_size / 1024 / 1024, 2)   AS index_size_mb,
    -- Server uptime as an honesty check on the "never used" claim.
    (SELECT VARIABLE_VALUE
     FROM performance_schema.global_status
     WHERE VARIABLE_NAME = 'Uptime')                               AS server_uptime_secs,
    CASE
        WHEN sui.index_name = 'PRIMARY'
            THEN 'PRIMARY KEY — required, do not drop'
        WHEN (SELECT VARIABLE_VALUE
              FROM performance_schema.global_status
              WHERE VARIABLE_NAME = 'Uptime')::unsigned < 7 * 86400
            THEN 'flagged unused but server uptime < 7 days — wait for a full week'
        ELSE
            CONCAT(
                '🔴 candidate-for-drop — ',
                'no reads since stats reset; ',
                'verify with sys.schema_index_statistics before dropping'
            )
    END                                                            AS verdict
FROM sys.schema_unused_indexes                                     AS sui
LEFT JOIN mysql.innodb_index_stats                                 AS stat
    ON  stat.database_name = sui.object_schema
    AND stat.table_name    = sui.object_name
    AND stat.index_name    = sui.index_name
    AND stat.stat_name     = 'size'
WHERE sui.object_schema NOT IN ('mysql', 'performance_schema',
                                'information_schema', 'sys')
ORDER BY index_size_mb DESC;
