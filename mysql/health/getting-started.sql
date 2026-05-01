-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : getting-started                                 ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (status variables and information_schema) ║
-- ║  Permissions   : standard SELECT — no special grants needed       ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-getting-started  ║
-- ║  Inspired by   : MySQL Reference Manual — Server Administration   ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌱 Newborn  (your first MySQL diagnostic — tutorial style) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Your very first MySQL diagnostic, with extensive comments. By
--       the end you'll know the difference between system variables
--       (settings) and status variables (counters), what
--       performance_schema is, and how to ask "where am I?".
--   TR: İlk MySQL tanı sorgun, bol açıklamalı. Sonunda system
--       variables (ayarlar) ile status variables (sayaçlar)
--       arasındaki farkı, performance_schema'nın ne olduğunu ve
--       "neredeyim?" sorusunu nasıl soracağını bileceksin.
--
-- The two variable kinds / İki değişken türü:
--   EN: System variables (`@@variable_name` or
--       performance_schema.global_variables) are settings — usually
--       set in my.cnf, defining how the server behaves.
--       Status variables (performance_schema.global_status) are
--       counters — they track what the server has done since startup.
--   TR: System variables (`@@variable_name` veya
--       performance_schema.global_variables) ayarlardır — genelde
--       my.cnf'de set edilir, sunucunun nasıl davranacağını belirler.
--       Status variables (performance_schema.global_status)
--       sayaçlardır — başlangıçtan beri sunucunun ne yaptığını izler.

-- ── 1. WHERE AM I? · NEREDEYİM? ────────────────────────────────────
SELECT
    'IDENTITY'                                              AS section,
    @@version                                               AS mysql_version,
    @@version_compile_os                                    AS compile_os,
    @@hostname                                              AS hostname,
    @@server_id                                             AS server_id,
    -- read_only=ON usually means this is a replica.
    @@read_only                                             AS is_read_only,
    -- sql_mode controls behaviour quirks like strict mode. Worth knowing.
    @@sql_mode                                              AS sql_mode,
    @@time_zone                                             AS time_zone;

-- ── 2. HOW LONG HAS THIS BEEN UP? · NE KADAR SÜREDİR AÇIK? ────────
SELECT
    'UPTIME'                                                AS section,
    VARIABLE_VALUE                                          AS uptime_seconds,
    -- Convert to days/hours/minutes for readability
    CONCAT(
        FLOOR(VARIABLE_VALUE / 86400), 'd ',
        FLOOR(MOD(VARIABLE_VALUE, 86400) / 3600), 'h ',
        FLOOR(MOD(VARIABLE_VALUE, 3600) / 60), 'm'
    )                                                       AS uptime_pretty
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Uptime';

-- ── 3. WHO IS CONNECTED? · KİM BAĞLI? ──────────────────────────────
-- Three useful counters: how many threads are connected (sessions),
-- how many are running (doing work right now), and the high-water
-- mark since startup.
SELECT
    'CONNECTIONS'                                           AS section,
    MAX(CASE WHEN VARIABLE_NAME = 'Threads_connected'
             THEN VARIABLE_VALUE END)                       AS threads_connected,
    MAX(CASE WHEN VARIABLE_NAME = 'Threads_running'
             THEN VARIABLE_VALUE END)                       AS threads_running,
    MAX(CASE WHEN VARIABLE_NAME = 'Max_used_connections'
             THEN VARIABLE_VALUE END)                       AS max_used_connections_ever,
    -- And the configured ceiling, for context.
    @@max_connections                                       AS configured_max_connections
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN ('Threads_connected', 'Threads_running',
                        'Max_used_connections');

-- ── 4. WHAT DATABASES EXIST? · HANGİ VERİTABANLARI VAR? ────────────
SELECT
    'DATABASES'                                             AS section,
    SCHEMA_NAME                                             AS database_name,
    DEFAULT_CHARACTER_SET_NAME                              AS charset,
    DEFAULT_COLLATION_NAME                                  AS collation
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('mysql', 'performance_schema',
                          'information_schema', 'sys')
ORDER BY SCHEMA_NAME;

-- ── 5. STORAGE ENGINES · DEPOLAMA MOTORLARI ───────────────────────
-- Different tables can use different engines. Almost everything you
-- care about uses InnoDB. Anything not InnoDB is worth knowing about.
SELECT
    'ENGINES'                                               AS section,
    ENGINE                                                  AS storage_engine,
    SUPPORT                                                 AS support_level,
    TRANSACTIONS                                            AS supports_transactions,
    CASE WHEN ENGINE = 'InnoDB' AND SUPPORT = 'DEFAULT'
         THEN '✅ InnoDB is default — what you expect on modern MySQL'
         WHEN SUPPORT = 'DEFAULT'
         THEN '⚠️ default engine is not InnoDB — investigate'
    END                                                     AS note
FROM information_schema.ENGINES
WHERE SUPPORT IN ('DEFAULT', 'YES')
ORDER BY (SUPPORT = 'DEFAULT') DESC, ENGINE;

-- Next steps / Sıradaki adımlar:
--   EN: Read mysql/health/instance-overview.sql for the polished
--       version, then mysql/performance/top-queries.sql.
--   TR: Cilalanmış sürümü için mysql/health/instance-overview.sql,
--       sonra mysql/performance/top-queries.sql.
