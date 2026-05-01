-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : top-queries                                     ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (single performance_schema scan)       ║
-- ║  Permissions   : SELECT on performance_schema.events_statements_*║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-top-queries    ║
-- ║  Inspired by   : MySQL Reference Manual — Performance Schema     ║
-- ║                  Statement Summary Tables (dev.mysql.com)         ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-07-04                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the top queries by cumulative latency from
-- performance_schema.events_statements_summary_by_digest. The digest
-- table normalizes by query shape, so different parameter values for
-- the same query collapse into one row.
--
-- Pre-flight check:
--   SELECT @@performance_schema;          -- must be 1
--   SELECT @@max_digest_length;           -- non-zero (default 1024)
--
-- The view truncates query text to MAX_DIGEST_LENGTH and stores a hash
-- as DIGEST. Use the digest column as a stable identifier across runs;
-- DIGEST_TEXT is the normalized form for human reading.
--
-- All times in performance_schema are reported in picoseconds; we
-- convert to milliseconds for readability.

SELECT
    ROW_NUMBER() OVER (ORDER BY SUM_TIMER_WAIT DESC)              AS `rank`,
    DIGEST                                                         AS query_digest,
    IFNULL(SCHEMA_NAME, '<no schema>')                             AS schema_name,
    COUNT_STAR                                                     AS executions,
    ROUND(SUM_TIMER_WAIT / 1e9, 2)                                 AS total_latency_ms,
    ROUND((SUM_TIMER_WAIT / NULLIF(COUNT_STAR, 0)) / 1e9, 2)       AS avg_latency_ms,
    ROUND(MIN_TIMER_WAIT / 1e9, 2)                                 AS min_latency_ms,
    ROUND(MAX_TIMER_WAIT / 1e9, 2)                                 AS max_latency_ms,
    SUM_ROWS_EXAMINED                                              AS total_rows_examined,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(COUNT_STAR, 0))               AS avg_rows_examined,
    SUM_ROWS_SENT                                                  AS total_rows_sent,
    SUM_ERRORS                                                     AS total_errors,
    SUM_NO_INDEX_USED                                              AS exec_no_index_used,
    SUM_NO_GOOD_INDEX_USED                                         AS exec_no_good_index_used,
    FIRST_SEEN,
    LAST_SEEN,
    LEFT(DIGEST_TEXT, 200)                                         AS query_preview
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME IS NULL OR SCHEMA_NAME NOT IN ('mysql', 'performance_schema',
                                                  'information_schema', 'sys')
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 25;
