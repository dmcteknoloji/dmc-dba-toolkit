-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : orphaned-users                                  ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟢 Light  (catalog scan across databases)        ║
-- ║  Permissions   : VIEW DEFINITION on each user database           ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#orphaned-users       ║
-- ║  Inspired by   : sp_change_users_login (deprecated) and the      ║
-- ║                  Microsoft Learn "orphaned users" troubleshooting║
-- ║                  guide. Approach modernised; code original.      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-15                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Database users whose SID does not match any server login are    ║
-- ║  "orphaned". They appear in the database, hold permissions, and  ║
-- ║  yet nobody can log in as them. This usually happens after a     ║
-- ║  restore from a different server, or after a login is dropped    ║
-- ║  without cleaning up its database users. Auditors hate them and  ║
-- ║  attackers love them.                                            ║
-- ╚══════════════════════════════════════════════════════════════════╝

IF OBJECT_ID('tempdb..#orphans') IS NOT NULL DROP TABLE #orphans;
CREATE TABLE #orphans (
    database_name sysname,
    user_name     sysname,
    user_type     nvarchar(60),
    user_sid      varbinary(85),
    create_date   datetime,
    modify_date   datetime
);

DECLARE @sql nvarchar(max) = N'';

SELECT @sql = @sql + N'
USE ' + QUOTENAME(d.name) + N';
INSERT INTO #orphans
SELECT
    DB_NAME() AS database_name,
    dp.name,
    dp.type_desc,
    dp.sid,
    dp.create_date,
    dp.modify_date
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.type IN (''S'',''U'',''G'')             -- SQL, Windows user, Windows group
  AND dp.principal_id > 4                        -- skip dbo, guest, INFORMATION_SCHEMA, sys
  AND dp.authentication_type_desc <> ''NONE''    -- skip role-only / external in Mongo-like cases
  AND dp.sid IS NOT NULL
  AND sp.sid IS NULL;
'
FROM sys.databases AS d
WHERE d.state_desc = 'ONLINE'
  AND d.database_id > 4
  AND d.is_read_only = 0;

EXEC sp_executesql @sql;

SELECT
    database_name,
    user_name,
    user_type,
    -- Human-readable SID — useful when comparing to AD or another server.
    CONVERT(varchar(258), user_sid, 1)            AS user_sid_hex,
    create_date,
    modify_date,
    CASE
        WHEN user_type = N'WINDOWS_GROUP'
            THEN N'AD group with no matching server login — group may have been removed'
        WHEN user_type = N'WINDOWS_USER'
            THEN N'AD user with no matching server login — login dropped or DB restored from elsewhere'
        WHEN user_type = N'SQL_USER'
            THEN N'SQL user with no matching server login — typically post-restore'
    END                                           AS note
FROM #orphans
ORDER BY database_name, user_name;

DROP TABLE #orphans;
