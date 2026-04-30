-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : blocking-chain                                  ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : blocking                                        ║
-- ║  Impact        : 🟢 Light  (DMV scan, no waits or locks taken)    ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#blocking-chain       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Returns the current blocking chain on the instance, with chain depth
-- and lead-blocker identification. Uses a recursive CTE rooted at sessions
-- that are blocking somebody but are not themselves blocked (the lead
-- blockers), then walks down the chain.
--
-- A row with chain_depth = 0 is the head of a chain (the session everyone
-- is ultimately waiting on). chain_depth = 1, 2, ... are victims further
-- down the chain. is_lead_blocker = 1 marks the same heads, for clients
-- that prefer a flag over depth filtering.

;WITH blockers AS (
    SELECT DISTINCT blocking_session_id AS session_id
    FROM sys.dm_exec_requests
    WHERE blocking_session_id <> 0
),
chain AS (
    -- Anchor: lead blockers — they block somebody, but nobody blocks them.
    SELECT
        0                                AS chain_depth,
        CAST(1 AS BIT)                   AS is_lead_blocker,
        b.session_id,
        CAST(0 AS SMALLINT)              AS blocking_session_id
    FROM blockers AS b
    WHERE NOT EXISTS (
        SELECT 1
        FROM sys.dm_exec_requests AS r
        WHERE r.session_id = b.session_id
          AND r.blocking_session_id <> 0
    )

    UNION ALL

    -- Recurse: victims of anyone already in the chain.
    SELECT
        c.chain_depth + 1                AS chain_depth,
        CAST(0 AS BIT)                   AS is_lead_blocker,
        r.session_id,
        r.blocking_session_id
    FROM chain AS c
    JOIN sys.dm_exec_requests AS r
        ON r.blocking_session_id = c.session_id
)
SELECT
    c.chain_depth,
    c.is_lead_blocker,
    c.session_id,
    c.blocking_session_id,
    r.wait_time                          AS wait_time_ms,
    r.wait_type,
    r.wait_resource,
    DB_NAME(r.database_id)               AS database_name,
    s.login_name,
    s.host_name,
    s.program_name,
    SUBSTRING(
        st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
              WHEN -1 THEN DATALENGTH(st.text)
              ELSE r.statement_end_offset
          END - r.statement_start_offset) / 2) + 1
    )                                    AS query_text
FROM chain AS c
LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = c.session_id
LEFT JOIN sys.dm_exec_requests AS r ON r.session_id = c.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
ORDER BY c.session_id, c.chain_depth
OPTION (MAXRECURSION 100);
