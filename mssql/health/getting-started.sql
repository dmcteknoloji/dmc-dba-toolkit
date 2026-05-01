-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : getting-started                                 ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (catalog views and SERVERPROPERTY)     ║
-- ║  Permissions   : public — every login can run this                ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-getting-started ║
-- ║  Inspired by   : Microsoft Learn — getting-started DMV tutorials  ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🌱 Newborn  (your first SQL Server query — tutorial style) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Your very first diagnostic query, with extensive comments. Run
--       this on any SQL Server you have access to. Read the output
--       row by row alongside the comments below — you'll come away
--       knowing what a "DMV" is, what `SERVERPROPERTY` does, and how
--       to ask "where am I and what is this server?" in pure T-SQL.
--   TR: Senin ilk tanı sorgun, bol açıklamalı. Erişimin olan herhangi
--       bir SQL Server'da çalıştır. Çıktıyı satır satır aşağıdaki
--       yorumlarla birlikte oku — "DMV" nedir, `SERVERPROPERTY` ne
--       işe yarar, "neredeyim ve bu sunucu nedir?" sorusunu saf
--       T-SQL ile nasıl sorulur — öğrenmiş olarak çıkacaksın.
--
-- What is a DMV? / DMV nedir?
--   EN: "Dynamic Management View" — read-only views that SQL Server
--       maintains in memory to expose runtime state. They start with
--       `sys.dm_*`. They are the canonical way to ask SQL Server
--       about itself.
--   TR: "Dynamic Management View" — SQL Server'ın bellekte tuttuğu,
--       çalışma zamanı durumunu açan salt-okunur view'lar. `sys.dm_*`
--       ile başlarlar. SQL Server'a kendisini sormanın canonical
--       yoludur.

-- ── 1. WHERE AM I? · NEREDEYİM? ────────────────────────────────────
-- SERVERPROPERTY is a built-in function. It returns a single value
-- about the server. We pick the four most useful properties.
SELECT
    'IDENTITY'                                              AS section,
    SERVERPROPERTY('ProductVersion')                        AS product_version,
    SERVERPROPERTY('Edition')                               AS edition,
    SERVERPROPERTY('ProductLevel')                          AS product_level,
    SERVERPROPERTY('Collation')                             AS collation,
    -- ServerName is what client connection strings see.
    @@SERVERNAME                                            AS server_name,
    -- DB_NAME() returns the database your session is currently using.
    DB_NAME()                                               AS current_database;

-- ── 2. HOW LONG HAS THIS SERVER BEEN UP? · NE KADAR SÜREDİR AÇIK? ─
-- sys.dm_os_sys_info exposes one row of OS-level info. The
-- sqlserver_start_time column is the moment SQL Server's process
-- started; subtracting from now gives uptime.
SELECT
    'UPTIME'                                                AS section,
    sqlserver_start_time                                    AS started_at_utc,
    DATEDIFF(MINUTE, sqlserver_start_time, SYSUTCDATETIME()) AS uptime_minutes,
    -- Pretty-print: days/hours/minutes
    CONCAT(
        DATEDIFF(MINUTE, sqlserver_start_time, SYSUTCDATETIME()) / 1440, 'd ',
        (DATEDIFF(MINUTE, sqlserver_start_time, SYSUTCDATETIME()) % 1440) / 60, 'h ',
        DATEDIFF(MINUTE, sqlserver_start_time, SYSUTCDATETIME()) % 60, 'm'
    )                                                       AS uptime_pretty
FROM sys.dm_os_sys_info;

-- ── 3. WHO IS CONNECTED RIGHT NOW? · KİM BAĞLI ŞU AN? ──────────────
-- sys.dm_exec_sessions has one row per session. is_user_process = 1
-- excludes SQL Server's own internal sessions.
SELECT
    'SESSIONS'                                              AS section,
    COUNT(*)                                                AS user_sessions,
    COUNT(DISTINCT login_name)                              AS distinct_logins,
    COUNT(DISTINCT host_name)                               AS distinct_hosts
FROM sys.dm_exec_sessions
WHERE is_user_process = 1;

-- ── 4. WHAT DATABASES EXIST? · HANGİ VERİTABANLARI VAR? ────────────
-- sys.databases is a catalog view (not a DMV — these don't change
-- much). It lists every database the server hosts.
SELECT
    'DATABASES'                                             AS section,
    name                                                    AS database_name,
    state_desc                                              AS state,
    recovery_model_desc                                     AS recovery_model,
    -- Skip the four system DBs to keep the output tight.
    create_date
FROM sys.databases
WHERE database_id > 4
ORDER BY name;

-- Next steps / Sıradaki adımlar:
--   EN: Read mssql/health/instance-overview.sql — same idea but more
--       polished. Then mssql/performance/top-cpu-queries.sql.
--   TR: mssql/health/instance-overview.sql'i oku — aynı fikrin
--       cilalanmış hâli. Sonra mssql/performance/top-cpu-queries.sql.
