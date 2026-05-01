-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : replication-lag-snapshot                        ║
-- ║  Engine        : MySQL 8.0+ │ Aurora MySQL │ Percona Server 8.0+ ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (performance_schema replication views) ║
-- ║  Permissions   : SELECT on performance_schema.replication_*      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-replication-lag-snapshot ║
-- ║  Inspired by   : MySQL Reference Manual — Replication Performance║
-- ║                  Schema Tables.                                   ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: One row per call with the canonical replica-lag headline:
--       seconds behind primary, derived from the original commit
--       timestamp on the source vs now() on the replica. This is
--       the metric MySQL itself uses internally and the one that
--       matches what report consumers actually see (a row that is
--       N seconds out of date). Run on the *replica* — on a stand-
--       alone primary the lag column will be NULL.
--   TR: Çağrı başına tek satır, canonical replica-lag manşeti:
--       primary'nin gerisinde kalınan saniye, kaynak commit
--       timestamp'i vs replikadaki now() üzerinden. Bu MySQL'in
--       kendi içinde kullandığı metriktir ve rapor tüketicilerinin
--       gerçekten gördüğü ile eşleşir (N saniye eski satır).
--       *Replika*'da çalıştır — bağımsız primary'de lag NULL gelir.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 collects this from every replica every minute,
--   baselines normal lag per replica, and alerts on anomalies — see
--   https://github.com/dmcteknoloji.

SELECT
    NOW(6)                                                          AS sample_utc,
    @@hostname                                                      AS replica_hostname,
    @@server_id                                                     AS replica_server_id,
    @@read_only                                                     AS is_read_only,
    @@super_read_only                                               AS is_super_read_only,
    -- Connection state to source(s)
    (SELECT GROUP_CONCAT(DISTINCT CHANNEL_NAME)
     FROM performance_schema.replication_connection_status)         AS channels,
    (SELECT MAX(CASE WHEN SERVICE_STATE = 'OFF' THEN 1 ELSE 0 END)
     FROM performance_schema.replication_connection_status)         AS any_channel_off,
    -- Per-channel applier state (coordinator)
    (SELECT MAX(CASE WHEN SERVICE_STATE = 'OFF' THEN 1 ELSE 0 END)
     FROM performance_schema.replication_applier_status)            AS any_applier_off,
    -- Headline: seconds behind primary
    -- LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP is set on the
    -- source when the transaction commits; comparing to NOW(6) on the
    -- replica gives end-to-end propagation lag.
    (SELECT TIMESTAMPDIFF(
                SECOND,
                MAX(LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP),
                NOW(6))
     FROM performance_schema.replication_applier_status_by_worker)  AS lag_seconds,
    -- Last successful apply
    (SELECT MAX(LAST_APPLIED_TRANSACTION_END_APPLY_TIMESTAMP)
     FROM performance_schema.replication_applier_status_by_worker)  AS last_apply_ts,
    -- Worker fleet health
    (SELECT COUNT(*)
     FROM performance_schema.replication_applier_status_by_worker)  AS applier_workers_total,
    (SELECT COUNT(*)
     FROM performance_schema.replication_applier_status_by_worker
     WHERE SERVICE_STATE = 'ON')                                    AS applier_workers_running,
    -- Last error (any channel) — surfaces "broken applier" without parsing logs
    (SELECT IFNULL(MAX(LAST_ERROR_NUMBER), 0)
     FROM performance_schema.replication_applier_status)            AS last_applier_error_no,
    (SELECT MAX(LAST_ERROR_MESSAGE)
     FROM performance_schema.replication_applier_status
     WHERE LAST_ERROR_NUMBER <> 0)                                  AS last_applier_error_msg,
    -- Group replication state (NULL if not in use)
    (SELECT GROUP_CONCAT(MEMBER_STATE)
     FROM performance_schema.replication_group_members)             AS group_member_states,
    -- Verdict — single line for an alert subject
    CASE
        WHEN (SELECT MAX(CASE WHEN SERVICE_STATE = 'OFF' THEN 1 ELSE 0 END)
              FROM performance_schema.replication_applier_status) = 1
            THEN '🔴 applier OFF — replication broken, check last_applier_error_msg'
        WHEN (SELECT TIMESTAMPDIFF(
                        SECOND,
                        MAX(LAST_APPLIED_TRANSACTION_ORIGINAL_COMMIT_TIMESTAMP),
                        NOW(6))
              FROM performance_schema.replication_applier_status_by_worker) > 60
            THEN '🟠 lag > 60s'
        WHEN (SELECT IFNULL(MAX(LAST_ERROR_NUMBER), 0)
              FROM performance_schema.replication_applier_status) <> 0
            THEN '🟡 last applier error logged — review last_applier_error_msg'
    END                                                             AS verdict;
