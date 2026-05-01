-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : blocking-snapshot                               ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : monitoring                                      ║
-- ║  Impact        : 🟢 Light  (one DMV scan)                         ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-blocking-snapshot ║
-- ║  Inspired by   : sys.dm_exec_requests blocking_session_id —      ║
-- ║                  Microsoft Learn public reference.                ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Blocking is rarely a single moment — it's a pattern. To see
--       the pattern, you need a time series of "how many sessions
--       were blocked, how deep the longest chain went, how long the
--       lead blocker had been holding". This script returns one row
--       per call. Schedule every 30-60 seconds and the pattern
--       emerges in any chart tool.
--   TR: Blocking nadiren tek bir andır — bir paterndir. Pateni
--       görmek için "kaç oturum bloklanmıştı, en uzun zincir ne
--       kadar derindi, lead blocker ne kadar süredir tutuyordu"
--       zaman serisine ihtiyacın var. Bu script çağrı başına tek
--       satır verir. 30-60 saniyede bir çalıştır; herhangi bir
--       grafik aracında patern ortaya çıkar.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 records this snapshot every 30 seconds, alerts
--   when chain depth or lead-blocker age crosses thresholds, and
--   produces a weekly "top blocking patterns" report — see
--   https://github.com/dmcteknoloji.

WITH live AS (
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.wait_time            AS wait_ms,
        r.wait_type,
        r.wait_resource,
        r.database_id,
        s.host_name,
        s.program_name,
        s.login_name,
        SUBSTRING(st.text,
                  (r.statement_start_offset / 2) + 1,
                  ((CASE r.statement_end_offset
                        WHEN -1 THEN DATALENGTH(st.text)
                        ELSE r.statement_end_offset
                    END - r.statement_start_offset) / 2) + 1) AS query_text
    FROM sys.dm_exec_requests AS r
    LEFT JOIN sys.dm_exec_sessions AS s ON s.session_id = r.session_id
    OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
),
chain AS (
    -- Lead blockers: blocking somebody, not themselves blocked.
    SELECT DISTINCT live.session_id AS lead_id,
                    live.wait_ms    AS lead_wait_ms,
                    live.host_name  AS lead_host,
                    live.program_name AS lead_program,
                    live.login_name AS lead_login,
                    live.query_text AS lead_query
    FROM live
    WHERE EXISTS (SELECT 1 FROM live AS v
                  WHERE v.blocking_session_id = live.session_id)
      AND NOT EXISTS (SELECT 1 FROM live AS v2
                      WHERE v2.session_id = live.session_id
                        AND v2.blocking_session_id <> 0)
),
victims AS (
    SELECT COUNT(*) AS blocked_sessions
    FROM live
    WHERE blocking_session_id <> 0
)
SELECT
    SYSUTCDATETIME()                                          AS sample_utc,
    @@SERVERNAME                                              AS server_name,
    -- Headline counts
    (SELECT blocked_sessions FROM victims)                    AS blocked_sessions,
    (SELECT COUNT(*) FROM chain)                              AS lead_blockers,
    -- Of all victims, the longest one's wait time — useful for SLA-style alerts.
    (SELECT MAX(wait_ms) FROM live WHERE blocking_session_id <> 0)
                                                              AS longest_block_wait_ms,
    -- Lead blocker context (the worst one, by wait age)
    (SELECT TOP 1 lead_id          FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_session_id,
    (SELECT TOP 1 lead_wait_ms     FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_wait_ms,
    (SELECT TOP 1 lead_host        FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_host,
    (SELECT TOP 1 lead_program     FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_program,
    (SELECT TOP 1 lead_login       FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_login,
    (SELECT TOP 1 LEFT(lead_query, 200) FROM chain ORDER BY lead_wait_ms DESC)
                                                              AS top_lead_query_preview,
    -- Wait type breakdown of victims (commonly LCK_M_* but also PAGELATCH).
    (SELECT TOP 1 wait_type
     FROM live
     WHERE blocking_session_id <> 0
     GROUP BY wait_type
     ORDER BY COUNT(*) DESC)                                  AS dominant_wait_type;
