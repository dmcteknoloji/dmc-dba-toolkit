-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : ag-status                                       ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI (read replicas) ║
-- ║  Category      : ha                                              ║
-- ║  Impact        : 🟢 Light  (HA DMVs, no impact on the AG)         ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#ag-status            ║
-- ║  Inspired by   : sys.dm_hadr_* DMV family — Microsoft Learn      ║
-- ║                  Always On Availability Groups public docs.       ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-25                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Always On AG is the kind of feature where everything is fine    ║
-- ║  until it isn't, and when it isn't, the screens are full of      ║
-- ║  three-letter columns and DMV joins. This script consolidates    ║
-- ║  the four questions you actually need to answer first: which AG, ║
-- ║  which replica is primary, are all replicas synchronizing, and   ║
-- ║  is any database not joined to the AG it belongs to?             ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- Quick guard — Always On may be disabled on this instance.
IF SERVERPROPERTY('IsHadrEnabled') IS NULL
   OR CAST(SERVERPROPERTY('IsHadrEnabled') AS INT) = 0
BEGIN
    SELECT N'INFO' AS section,
           N'Always On is not enabled on this instance' AS message;
    RETURN;
END;

-- ── 1. AVAILABILITY GROUPS ─────────────────────────────────────────
SELECT
    'AG'                                                AS section,
    ag.name                                             AS ag_name,
    ag.failure_condition_level                          AS failure_cond_level,
    ag.health_check_timeout                             AS health_check_timeout_ms,
    ag.automated_backup_preference_desc                 AS backup_preference,
    ag.cluster_type_desc                                AS cluster_type,
    ar.replica_server_name                              AS primary_replica
FROM sys.availability_groups                AS ag
JOIN sys.dm_hadr_availability_replica_states AS rs
    ON rs.group_id = ag.group_id AND rs.role = 1
JOIN sys.availability_replicas              AS ar
    ON ar.replica_id = rs.replica_id;

-- ── 2. REPLICAS ────────────────────────────────────────────────────
SELECT
    'REPLICA'                                           AS section,
    ag.name                                             AS ag_name,
    ar.replica_server_name                              AS replica,
    rs.role_desc                                        AS role,
    rs.connected_state_desc                             AS connected_state,
    rs.synchronization_health_desc                      AS sync_health,
    ar.availability_mode_desc                           AS availability_mode,
    ar.failover_mode_desc                               AS failover_mode,
    ar.session_timeout                                  AS session_timeout_sec,
    rs.operational_state_desc                           AS operational_state,
    CASE
        WHEN rs.synchronization_health <> 2  -- 2 = HEALTHY
            THEN N'⚠️ replica is not HEALTHY'
        WHEN rs.connected_state <> 1          -- 1 = CONNECTED
            THEN N'⚠️ replica disconnected'
    END                                                 AS note
FROM sys.dm_hadr_availability_replica_states AS rs
JOIN sys.availability_replicas               AS ar
    ON ar.replica_id = rs.replica_id
JOIN sys.availability_groups                 AS ag
    ON ag.group_id = ar.group_id
ORDER BY ag.name, rs.role_desc;

-- ── 3. DATABASE-LEVEL STATE + LAG ─────────────────────────────────
SELECT
    'DB'                                                AS section,
    ag.name                                             AS ag_name,
    ar.replica_server_name                              AS replica,
    DB_NAME(drs.database_id)                            AS database_name,
    drs.synchronization_state_desc                      AS sync_state,
    drs.synchronization_health_desc                     AS sync_health,
    drs.suspend_reason_desc                             AS suspend_reason,
    -- log_send_queue_size is the volume queued *to* the secondary;
    -- redo_queue_size is the volume queued *for redo* on the secondary.
    -- Both in KB. Big numbers on either side = falling behind.
    drs.log_send_queue_size                             AS log_send_queue_kb,
    drs.redo_queue_size                                 AS redo_queue_kb,
    drs.last_sent_time,
    drs.last_received_time,
    drs.last_hardened_time,
    drs.last_redone_time,
    CASE
        WHEN drs.synchronization_state <> 2     -- 2 = SYNCHRONIZED
             AND drs.synchronization_state <> 1 -- 1 = SYNCHRONIZING
            THEN N'⚠️ db is not synchronizing'
        WHEN drs.log_send_queue_size > 100000   -- 100 MB queued
            THEN N'⚠️ log send queue > 100 MB — primary outpacing the link'
        WHEN drs.redo_queue_size > 100000
            THEN N'⚠️ redo queue > 100 MB — secondary CPU/IO bound'
    END                                                 AS note
FROM sys.dm_hadr_database_replica_states     AS drs
JOIN sys.availability_replicas               AS ar
    ON ar.replica_id = drs.replica_id
JOIN sys.availability_groups                 AS ag
    ON ag.group_id = ar.group_id
ORDER BY ag.name, ar.replica_server_name, DB_NAME(drs.database_id);
