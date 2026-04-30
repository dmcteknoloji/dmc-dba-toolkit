-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : innodb-row-lock-waits                           ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (status counters + summary)            ║
-- ║  Permissions   : SELECT on performance_schema.* and sys.*        ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-innodb-row-lock-waits ║
-- ║  Inspired by   : MySQL Reference Manual — InnoDB monitoring      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-08-22                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns InnoDB row-lock contention overview from two angles:
--   1. Cumulative counters from global status (since startup).
--   2. Currently held / requested locks per table from
--      performance_schema.data_locks (MySQL 8.0+) or its 5.7 equivalent.
--
-- For *who is blocking whom* live, see blocking-chain.sql.
-- For deadlocks, SHOW ENGINE INNODB STATUS\G remains the canonical
-- per-incident dump — this script is a continuous-monitoring view.

-- ── 1. Cumulative since startup ────────────────────────────────────
SELECT
    'CUMULATIVE'                                                  AS section,
    VARIABLE_NAME                                                 AS metric,
    VARIABLE_VALUE                                                AS value
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Innodb_row_lock_current_waits',
    'Innodb_row_lock_time',
    'Innodb_row_lock_time_avg',
    'Innodb_row_lock_time_max',
    'Innodb_row_lock_waits'
)
ORDER BY FIELD(VARIABLE_NAME,
    'Innodb_row_lock_current_waits',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_time',
    'Innodb_row_lock_time_avg',
    'Innodb_row_lock_time_max');

-- ── 2. Per-table lock pressure (MySQL 8.0+) ────────────────────────
-- Falls back to a notice on 5.7 where data_locks does not exist.
SELECT
    'PER_TABLE'                                                   AS section,
    OBJECT_SCHEMA                                                  AS schema_name,
    OBJECT_NAME                                                    AS table_name,
    LOCK_TYPE,
    LOCK_MODE,
    LOCK_STATUS,
    COUNT(*)                                                       AS lock_rows
FROM performance_schema.data_locks
WHERE OBJECT_SCHEMA NOT IN ('mysql', 'performance_schema',
                            'information_schema', 'sys')
GROUP BY OBJECT_SCHEMA, OBJECT_NAME, LOCK_TYPE, LOCK_MODE, LOCK_STATUS
ORDER BY lock_rows DESC
LIMIT 25;
