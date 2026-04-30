-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : connection-pressure                             ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (pg_stat_activity scan)                ║
-- ║  Permissions   : pg_read_all_stats (recommended) or superuser    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-connection-pressure║
-- ║  Inspired by   : PostgreSQL official monitoring docs              ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-17                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Postgres connection limits surprise people. max_connections is ║
-- ║  a global cap; superuser_reserved_connections eats into it; a   ║
-- ║  bad pgbouncer config can hold idle connections forever; an app ║
-- ║  pool can leak. This script answers four questions in one go:   ║
-- ║  how close are we to the cap, who is using the most slots, how  ║
-- ║  many connections are stuck in 'idle in transaction', and what  ║
-- ║  is the oldest one.                                              ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. HEADROOM ─────────────────────────────────────────────────────
SELECT
    'HEADROOM'                                          AS section,
    current_setting('max_connections')::int             AS max_connections,
    current_setting('superuser_reserved_connections')::int
                                                        AS superuser_reserved,
    (SELECT count(*) FROM pg_stat_activity)             AS connections_now,
    current_setting('max_connections')::int
        - (SELECT count(*) FROM pg_stat_activity)       AS available_now,
    round(100.0 * (SELECT count(*) FROM pg_stat_activity)
          / current_setting('max_connections')::int, 1) AS pct_used,
    CASE
        WHEN (SELECT count(*) FROM pg_stat_activity)
             > current_setting('max_connections')::int * 0.85
            THEN '🔴 over 85% of max_connections — at risk of refusing new sessions'
        WHEN (SELECT count(*) FROM pg_stat_activity)
             > current_setting('max_connections')::int * 0.6
            THEN '🟠 over 60% of max_connections — investigate'
    END                                                 AS note;

-- ── 2. BY DATABASE × USER × STATE ───────────────────────────────────
SELECT
    'BY_GROUP'                                          AS section,
    coalesce(datname, '<no db>')                        AS database_name,
    coalesce(usename, '<no user>')                      AS user_name,
    coalesce(application_name, '<no app>')              AS application,
    state,
    count(*)                                            AS connections,
    round(extract(epoch FROM
        avg(now() - state_change))::numeric, 1)         AS avg_state_age_secs,
    round(extract(epoch FROM
        max(now() - state_change))::numeric, 1)         AS max_state_age_secs
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY datname, usename, application_name, state
ORDER BY connections DESC;

-- ── 3. IDLE-IN-TRANSACTION DETAIL ───────────────────────────────────
-- This is the canonical "why is the database getting full" suspect.
-- Sessions in this state hold locks, prevent vacuum from cleaning up
-- dead tuples, and prevent the visibility horizon from advancing.
SELECT
    'IDLE_IN_XACT'                                      AS section,
    pid,
    datname                                             AS database_name,
    usename                                             AS user_name,
    application_name,
    client_addr,
    state,
    round(extract(epoch FROM (now() - xact_start))::numeric, 1)
                                                        AS xact_age_secs,
    left(query, 300)                                    AS last_query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND pid <> pg_backend_pid()
ORDER BY xact_start;
