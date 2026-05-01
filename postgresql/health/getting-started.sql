-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : getting-started                                 ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (catalog and built-in functions)       ║
-- ║  Permissions   : standard read — no special grants required       ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-getting-started    ║
-- ║  Inspired by   : PostgreSQL official tutorial documentation        ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌱 Newborn  (your first PostgreSQL query — tutorial style) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Your very first PostgreSQL diagnostic, with extensive comments.
--       Read along with the comments — by the end you'll know what
--       `pg_stat_*` views are, why `pg_is_in_recovery()` matters, and
--       how to answer "where am I and what does this cluster look like?".
--   TR: Sonsuz PostgreSQL tanı yolculuğunun ilk adımı, bol açıklamalı.
--       Yorumları takip ederek oku — sonunda `pg_stat_*` view'larının
--       ne olduğunu, `pg_is_in_recovery()`'nin neden önemli olduğunu
--       ve "neredeyim ve bu cluster nasıl?" sorusunu nasıl cevapladığını
--       bileceksin.
--
-- What is pg_stat_*? / pg_stat_* nedir?
--   EN: A family of views Postgres maintains in memory exposing live
--       cluster state — pg_stat_activity (current sessions),
--       pg_stat_database (per-database counters), pg_stat_replication
--       (replicas), and many more. These are the canonical "ask
--       Postgres about itself" interface.
--   TR: Postgres'in bellekte tuttuğu, canlı cluster durumunu açan
--       view ailesi — pg_stat_activity (anlık oturumlar),
--       pg_stat_database (DB başına sayaçlar), pg_stat_replication
--       (replikalar) ve dahası. "Postgres'e kendini sor" arayüzünün
--       canonical halidir.

-- ── 1. WHERE AM I? · NEREDEYİM? ────────────────────────────────────
SELECT
    'IDENTITY'                                              AS section,
    version()                                               AS pg_version,
    current_database()                                      AS current_db,
    current_user                                            AS current_user_name,
    inet_server_addr()                                      AS server_addr,
    -- This is the killer: are we writing or read-only? Standby (replica)
    -- nodes return TRUE; primaries return FALSE.
    pg_is_in_recovery()                                     AS is_standby,
    -- Cluster name is set in postgresql.conf; useful when you've got
    -- many similarly-named clusters.
    coalesce(nullif(current_setting('cluster_name'), ''),
             '<not set>')                                   AS cluster_name;

-- ── 2. HOW LONG HAS THIS BEEN UP? · NE KADAR SÜREDİR AÇIK? ────────
SELECT
    'UPTIME'                                                AS section,
    pg_postmaster_start_time()                              AS started_at,
    -- age() is a Postgres-native interval calculation
    age(now(), pg_postmaster_start_time())                  AS uptime,
    extract(epoch FROM (now() - pg_postmaster_start_time()))::int AS uptime_seconds;

-- ── 3. WHO IS CONNECTED? · KİM BAĞLI? ──────────────────────────────
-- pg_stat_activity is the canonical "what's happening now?" view.
-- One row per backend (connection). pg_backend_pid() is your own.
SELECT
    'CONNECTIONS'                                           AS section,
    count(*)                                                AS connections_total,
    count(*) FILTER (WHERE state = 'active')                AS active,
    count(*) FILTER (WHERE state = 'idle')                  AS idle,
    -- "idle in transaction" backends hold locks and prevent vacuum
    -- from cleaning up. Worth knowing about even on day one.
    count(*) FILTER (WHERE state = 'idle in transaction')   AS idle_in_xact,
    count(DISTINCT datname)                                 AS distinct_databases,
    count(DISTINCT usename)                                 AS distinct_users
FROM pg_stat_activity
WHERE pid <> pg_backend_pid();

-- ── 4. WHAT DATABASES EXIST? · HANGİ VERİTABANLARI VAR? ────────────
SELECT
    'DATABASES'                                             AS section,
    datname                                                 AS database_name,
    pg_size_pretty(pg_database_size(datname))               AS size,
    -- Encoding and collation matter for sort order and case folding.
    pg_encoding_to_char(encoding)                           AS encoding,
    datcollate                                              AS collation
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

-- ── 5. WHAT EXTENSIONS ARE INSTALLED? · HANGİ UZANTILAR YÜKLÜ? ─────
-- Extensions are how Postgres grows. pg_stat_statements is the most
-- important one for DBA work; check whether it's installed.
SELECT
    'EXTENSIONS'                                            AS section,
    extname                                                 AS extension_name,
    extversion                                              AS version,
    CASE
        WHEN extname = 'pg_stat_statements'
            THEN '✅ query stats are available — see top-queries.sql'
        WHEN extname = 'pgstattuple'
            THEN '✅ accurate bloat measurement is available'
        WHEN extname = 'pg_buffercache'
            THEN '✅ buffer cache contents are inspectable'
    END                                                     AS toolkit_relevance
FROM pg_extension
ORDER BY extname;

-- Next steps / Sıradaki adımlar:
--   EN: Read postgresql/health/instance-overview.sql, then
--       postgresql/performance/top-queries.sql.
--   TR: postgresql/health/instance-overview.sql'i oku, sonra
--       postgresql/performance/top-queries.sql.
