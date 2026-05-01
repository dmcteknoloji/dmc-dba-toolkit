-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : replication-status                              ║
-- ║  Engine        : MySQL 8.0+ │ Aurora MySQL │ Percona Server 8.0+ ║
-- ║  Category      : replication                                     ║
-- ║  Impact        : 🟢 Light  (performance_schema replication views) ║
-- ║  Permissions   : SELECT on performance_schema.replication_*      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-replication-status ║
-- ║  Inspired by   : MySQL Reference Manual — Replication Performance║
-- ║                  Schema Tables                                    ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-03-08                                      ║
-- ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the replication state of this server using the
-- performance_schema.replication_* views (MySQL 8.0+). Replaces
-- the legacy SHOW REPLICA STATUS / SHOW SLAVE STATUS commands with a
-- structured, parseable result.
--
-- Sections:
--   1. CONNECTION  — connection state to the source(s).
--   2. APPLIER     — coordinator/worker thread state and lag.
--   3. GROUP REPL  — only when group replication is active.
--
-- Run on the *replica* for the meaningful picture. On a stand-alone
-- primary, the connection / applier sections will be empty.

-- ── 1. CONNECTION (replica → source) ───────────────────────────────
SELECT
    'CONNECTION'                                                  AS section,
    CHANNEL_NAME,
    SERVICE_STATE                                                 AS service_state,
    CONCAT(HOST, ':', PORT)                                       AS source_endpoint,
    USER                                                          AS replication_user,
    CONCAT(
        'GTID auto-position=', AUTO_POSITION,
        ' | SSL=', IFNULL(SSL_ALLOWED, 'n/a')
    )                                                             AS connection_settings,
    LAST_HEARTBEAT_TIMESTAMP                                      AS last_heartbeat,
    LAST_ERROR_NUMBER                                             AS last_error_no,
    LAST_ERROR_MESSAGE                                            AS last_error_msg
FROM performance_schema.replication_connection_configuration
JOIN performance_schema.replication_connection_status USING (CHANNEL_NAME);

-- ── 2. APPLIER (coordinator + workers) ─────────────────────────────
SELECT
    'APPLIER'                                                     AS section,
    CHANNEL_NAME,
    SERVICE_STATE                                                 AS coord_state,
    REMAINING_DELAY                                               AS remaining_delay,
    LAST_ERROR_NUMBER                                             AS last_error_no,
    LAST_ERROR_MESSAGE                                            AS last_error_msg
FROM performance_schema.replication_applier_status
ORDER BY CHANNEL_NAME;

-- ── 3. APPLIER LAG (worker view, MySQL 8.0+) ───────────────────────
SELECT
    'APPLIER_LAG'                                                 AS section,
    CHANNEL_NAME,
    SUM(CASE WHEN SERVICE_STATE = 'ON' THEN 1 ELSE 0 END)         AS workers_running,
    COUNT(*)                                                      AS workers_total,
    MAX(LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP)             AS last_apply_ts,
    -- Lag in seconds: now − last applied transaction's original commit ts.
    -- Reflects end-to-end replica lag for sources that emit GTIDs.
    TIMESTAMPDIFF(
        SECOND,
        MAX(LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP),
        NOW(6)
    )                                                             AS lag_seconds
FROM performance_schema.replication_applier_status_by_worker
GROUP BY CHANNEL_NAME;

-- ── 4. GROUP REPLICATION (only if active) ──────────────────────────
SELECT
    'GROUP_REPL'                                                  AS section,
    MEMBER_ID                                                     AS member_id,
    MEMBER_HOST                                                   AS member_host,
    MEMBER_PORT                                                   AS member_port,
    MEMBER_STATE                                                  AS member_state,
    MEMBER_ROLE                                                   AS member_role,
    MEMBER_VERSION                                                AS member_version
FROM performance_schema.replication_group_members
ORDER BY MEMBER_ROLE, MEMBER_HOST;
