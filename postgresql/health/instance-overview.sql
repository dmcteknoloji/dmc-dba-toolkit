-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : instance-overview                               ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (server settings + counts)             ║
-- ║  Permissions   : pg_read_all_stats; standard read on catalogs    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-instance-overview ║
-- ║  Inspired by   : PostgreSQL official monitoring docs              ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-02-25                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- One-screen summary of this PostgreSQL cluster: identity (version, data
-- directory, role), workload (databases, connections, longest running
-- transaction), and a few stability-relevant settings (max_connections,
-- shared_buffers, work_mem, autovacuum).
--
-- Result is a single union-shaped table with a `section` discriminator
-- so it ships clean into a dashboard or CSV.

WITH stats AS (
    SELECT
        (SELECT count(*) FROM pg_database WHERE datistemplate = false) AS db_count,
        (SELECT count(*) FROM pg_stat_activity
         WHERE pid <> pg_backend_pid())                              AS conn_total,
        (SELECT count(*) FROM pg_stat_activity
         WHERE state = 'active' AND pid <> pg_backend_pid())         AS conn_active,
        (SELECT count(*) FROM pg_stat_activity
         WHERE state = 'idle in transaction'
           AND pid <> pg_backend_pid())                              AS conn_idle_in_xact,
        (SELECT coalesce(extract(epoch FROM (now() - min(xact_start)))::int, 0)
         FROM pg_stat_activity
         WHERE state <> 'idle' AND xact_start IS NOT NULL
           AND pid <> pg_backend_pid())                              AS oldest_xact_secs
)
SELECT * FROM (
    -- ── IDENTITY ────────────────────────────────────────────────
    VALUES
    ('IDENTITY', 'version',      version(),                                NULL),
    ('IDENTITY', 'server_role',
        CASE WHEN pg_is_in_recovery() THEN 'standby (in recovery)'
             ELSE 'primary' END,
        NULL),
    ('IDENTITY', 'data_directory',
        coalesce(current_setting('data_directory', true),
                 '<not exposed in this edition>'),
        NULL),
    ('IDENTITY', 'cluster_name',
        coalesce(nullif(current_setting('cluster_name', true), ''),
                 '<not set>'),
        NULL),
    ('IDENTITY', 'server_started',
        pg_postmaster_start_time()::text,
        ('uptime: ' ||
         age(now(), pg_postmaster_start_time())::text)::text),
    ('IDENTITY', 'max_connections',
        current_setting('max_connections'),
        NULL),
    ('IDENTITY', 'shared_buffers',
        current_setting('shared_buffers'),
        NULL),
    ('IDENTITY', 'work_mem',
        current_setting('work_mem'),
        NULL),
    ('IDENTITY', 'autovacuum',
        current_setting('autovacuum'),
        CASE WHEN current_setting('autovacuum') = 'off'
             THEN 'autovacuum is off — table bloat will accumulate' END)
) AS t(section, metric, value, note)

UNION ALL

SELECT 'WORKLOAD', 'database_count', s.db_count::text, NULL FROM stats AS s
UNION ALL
SELECT 'WORKLOAD', 'connections_total', s.conn_total::text, NULL FROM stats AS s
UNION ALL
SELECT 'WORKLOAD', 'connections_active', s.conn_active::text, NULL FROM stats AS s
UNION ALL
SELECT 'WORKLOAD', 'connections_idle_in_xact', s.conn_idle_in_xact::text,
       CASE WHEN s.conn_idle_in_xact > 0
            THEN 'idle-in-transaction backends hold locks; investigate'
       END
FROM stats AS s
UNION ALL
SELECT 'WORKLOAD', 'oldest_running_xact_secs', s.oldest_xact_secs::text,
       CASE WHEN s.oldest_xact_secs > 300
            THEN 'long-running transaction blocks vacuum and bloat builds up'
       END
FROM stats AS s

ORDER BY 1, 2;
