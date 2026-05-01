-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : error-log-last-24h                              ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟡 Medium  (xp_readerrorlog walks current log)   ║
-- ║  Permissions   : securityadmin or membership in role with        ║
-- ║                  EXECUTE on master.sys.xp_readerrorlog           ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#error-log-last-24h   ║
-- ║  Inspired by   : xp_readerrorlog parameters — Microsoft Learn    ║
-- ║                  public reference (system stored procedure).      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-19                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  When something breaks at 3 AM, you almost always need three     ║
-- ║  things from the SQL Server error log: severity-17+ errors,      ║
-- ║  failed logins, and disk/IO complaints. Reading the raw log file ║
-- ║  through SSMS is slow and the GUI lacks a "last 24 hours" filter.║
-- ║  This script does the time and severity filtering server-side.   ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Walks the *current* error log file (number 0). To check older logs,
-- change the @log_file argument. SQL Server retains 6 historical logs
-- by default; many shops bump this to 30 — which buys a month of
-- evidence after an incident.

DECLARE @log_file INT = 0;
DECLARE @start    DATETIME = DATEADD(HOUR, -24, SYSDATETIME());
DECLARE @end      DATETIME = SYSDATETIME();

IF OBJECT_ID('tempdb..#errlog') IS NOT NULL DROP TABLE #errlog;
CREATE TABLE #errlog (
    log_date     DATETIME,
    process_info NVARCHAR(64),
    log_text     NVARCHAR(MAX)
);

INSERT INTO #errlog
EXEC master.sys.xp_readerrorlog
    @log_file,                         -- 0 = current log
    1,                                 -- 1 = SQL Server log (2 = SQL Agent)
    NULL, NULL,                        -- no text filter (we filter below)
    @start, @end,                      -- time window
    N'asc';                            -- chronological

-- Severity tagging — text-pattern based because the error log doesn't
-- expose severity as a column. Patterns below are stable across the
-- supported version range.
SELECT
    log_date,
    process_info,
    CASE
        WHEN log_text LIKE N'%Severity:_17%'
          OR log_text LIKE N'%Severity:_1[8-9]%'
          OR log_text LIKE N'%Severity:_2[0-5]%'
                                                     THEN N'🔴 Severity 17+'
        WHEN log_text LIKE N'%Login failed%'
          OR log_text LIKE N'%Cannot authenticate%'   THEN N'🟠 Login failure'
        WHEN log_text LIKE N'%I/O is frozen%'
          OR log_text LIKE N'%Operating system error%'
          OR log_text LIKE N'%took longer than 15 seconds%'
                                                     THEN N'🟡 IO/storage warning'
        WHEN log_text LIKE N'%Memory Manager%'
          OR log_text LIKE N'%out of memory%'        THEN N'🟡 Memory pressure'
        WHEN log_text LIKE N'%deadlock%'
          OR log_text LIKE N'%Process %was deadlocked%'
                                                     THEN N'🟡 Deadlock'
        WHEN log_text LIKE N'%backup%failed%'
          OR log_text LIKE N'%RESTORE FAILED%'        THEN N'🔴 Backup/restore failure'
        WHEN log_text LIKE N'%Recovery is writing%'
          OR log_text LIKE N'%Starting up database%'  THEN N'ℹ️ Startup/recovery'
        ELSE N'  '
    END                                              AS classification,
    log_text
FROM #errlog
WHERE
    -- Filter to the categories above; strip routine "Login succeeded"
    -- and similar chatter unless severity 17+.
    log_text LIKE N'%Severity:_17%'
    OR log_text LIKE N'%Severity:_1[8-9]%'
    OR log_text LIKE N'%Severity:_2[0-5]%'
    OR log_text LIKE N'%Login failed%'
    OR log_text LIKE N'%Cannot authenticate%'
    OR log_text LIKE N'%I/O is frozen%'
    OR log_text LIKE N'%Operating system error%'
    OR log_text LIKE N'%took longer than 15 seconds%'
    OR log_text LIKE N'%Memory Manager%'
    OR log_text LIKE N'%out of memory%'
    OR log_text LIKE N'%deadlock%'
    OR log_text LIKE N'%Process %was deadlocked%'
    OR log_text LIKE N'%backup%failed%'
    OR log_text LIKE N'%RESTORE FAILED%'
    OR log_text LIKE N'%Recovery is writing%'
ORDER BY log_date;

DROP TABLE #errlog;
