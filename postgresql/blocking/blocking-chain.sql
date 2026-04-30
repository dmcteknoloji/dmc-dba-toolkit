-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : blocking-chain                                  ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : blocking                                        ║
-- ║  Impact        : 🟢 Light  (catalog + activity view scan)         ║
-- ║  Permissions   : pg_read_all_stats (recommended) or superuser    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-blocking-chain    ║
-- ║  Inspired by   : pg_blocking_pids() — official PostgreSQL func   ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-11-19                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the current blocking chain on the cluster, with chain depth
-- and lead-blocker identification. Uses pg_blocking_pids(), the
-- recommended way to detect lock waiters since PostgreSQL 9.6, and walks
-- the chain with a recursive CTE.
--
-- pg_blocking_pids() returns the array of process IDs that are blocking
-- the given PID. We anchor on backends that block someone but are not
-- themselves blocked (the "lead blockers"), then recurse into victims.
--
-- A chain_depth = 0 row is the head of a chain — the session everyone
-- else is ultimately waiting on. is_lead_blocker mirrors this as a
-- boolean for clients that prefer flags over depth filtering.

WITH RECURSIVE
blockers AS (
    SELECT DISTINCT unnest(pg_blocking_pids(pid)) AS pid
    FROM pg_stat_activity
    WHERE pid <> pg_backend_pid()
),
chain AS (
    -- Anchor: lead blockers — they block somebody, nobody blocks them.
    SELECT
        0                              AS chain_depth,
        true                           AS is_lead_blocker,
        b.pid,
        NULL::int                      AS blocked_by_pid
    FROM blockers AS b
    WHERE cardinality(pg_blocking_pids(b.pid)) = 0

    UNION ALL

    -- Recurse: victims of anyone already in the chain.
    SELECT
        c.chain_depth + 1              AS chain_depth,
        false                          AS is_lead_blocker,
        a.pid,
        c.pid                          AS blocked_by_pid
    FROM chain AS c
    JOIN pg_stat_activity AS a
        ON c.pid = ANY (pg_blocking_pids(a.pid))
)
SELECT
    c.chain_depth,
    c.is_lead_blocker,
    c.pid,
    c.blocked_by_pid,
    a.datname                          AS database_name,
    a.usename                          AS user_name,
    a.application_name,
    a.client_addr,
    a.state,
    a.wait_event_type,
    a.wait_event,
    round(extract(epoch FROM (now() - a.xact_start))::numeric, 2)
                                       AS xact_age_seconds,
    round(extract(epoch FROM (now() - a.query_start))::numeric, 2)
                                       AS query_age_seconds,
    left(a.query, 300)                 AS query_preview
FROM chain AS c
JOIN pg_stat_activity AS a USING (pid)
ORDER BY c.pid, c.chain_depth;
