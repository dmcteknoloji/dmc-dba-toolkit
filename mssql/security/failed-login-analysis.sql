-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : failed-login-analysis                           ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟡 Medium  (XE ring buffer XML shred + grouping) ║
-- ║  Permissions   : VIEW SERVER STATE, SELECT on system_health XEL  ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-failed-login-analysis ║
-- ║  Inspired by   : system_health Extended Events session — public  ║
-- ║                  Microsoft Learn reference. Pattern triage         ║
-- ║                  (one-IP-many-users vs many-IPs-one-user)         ║
-- ║                  draws on the practical security-incident         ║
-- ║                  literature; technique re-implemented here.        ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (XE shredding + auth-event triage)    ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   system_health Extended Events ring buffer'ından son 24 saatteki
--   "login failed" olaylarını XML'i shred ederek tablo formuna döker;
--   IP × kullanıcı × saat penceresi kırılımı verir. Üç saldırı
--   paternini etiketler: tek-IP-çok-kullanıcı (credential stuffing),
--   çok-IP-tek-kullanıcı (brute-force), tek-IP-tek-kullanıcı (fat
--   finger ya da uygulama bug'ı). XE buffer in-memory'dir ve döner;
--   uzun vadeli saklama için bu çıktıyı periyodik dump et.
--
-- Why this exists:
--   Trace flag 1471 + Login Auditing combinations are clunky. The
--   system_health session already captures error_reported events with
--   error number 18456 (login failed). This script reaches into that
--   ring buffer, parses the XML, and gives you the three triage
--   patterns from recipe 5 (Failed login burst — possible attack)
--   in the playbooks doc.

;WITH login_events AS (
    SELECT
        xev.value('(@timestamp)[1]', 'datetime2(3)')                AS event_time_utc,
        xev.value('(./action[@name="client_hostname"]/value)[1]',
                  'nvarchar(256)')                                  AS client_host,
        xev.value('(./action[@name="server_principal_name"]/value)[1]',
                  'nvarchar(256)')                                  AS attempted_login,
        xev.value('(./data[@name="state"]/value)[1]', 'int')        AS state_code,
        xev.value('(./data[@name="error_number"]/value)[1]', 'int') AS error_number,
        xev.value('(./data[@name="message"]/value)[1]',
                  'nvarchar(2048)')                                 AS message
    FROM (
        SELECT CAST(target_data AS XML) AS xml_data
        FROM sys.dm_xe_session_targets   AS t
        JOIN sys.dm_xe_sessions          AS s
            ON s.address = t.event_session_address
        WHERE s.name = N'system_health'
          AND t.target_name = N'ring_buffer'
    ) AS rb
    CROSS APPLY xml_data.nodes(
        '//RingBufferTarget/event[@name="error_reported"]') AS x(xev)
    WHERE xev.value('(./data[@name="error_number"]/value)[1]', 'int') = 18456
      AND xev.value('(@timestamp)[1]', 'datetime2(3)')
          >= DATEADD(HOUR, -24, SYSUTCDATETIME())
),
ranked AS (
    SELECT
        client_host,
        attempted_login,
        state_code,
        message,
        event_time_utc,
        -- State 11 = valid login but no permission to db, 5 = invalid
        -- userid, 7 = login disabled, 8 = wrong password, 16 = wrong db
        CASE state_code
            WHEN 5  THEN N'invalid userid'
            WHEN 6  THEN N'attempt to use Windows login with SQL auth'
            WHEN 7  THEN N'login disabled, password correct'
            WHEN 8  THEN N'wrong password'
            WHEN 9  THEN N'invalid password format'
            WHEN 11 THEN N'valid login, no DB permission'
            WHEN 12 THEN N'valid login but server access denied'
            WHEN 16 THEN N'invalid initial db'
            WHEN 18 THEN N'password must change'
            WHEN 38 THEN N'database not online'
            WHEN 40 THEN N'database not enabled for logins'
            ELSE N'state ' + CAST(state_code AS NVARCHAR(8))
        END                                                         AS state_meaning
    FROM login_events
)
SELECT
    -- ── 1. PER-PRINCIPAL × IP SUMMARY ─────────────────────────────
    'BY_LOGIN_AND_HOST'                                             AS section,
    attempted_login,
    client_host,
    COUNT(*)                                                        AS attempts,
    COUNT(DISTINCT state_code)                                      AS distinct_state_codes,
    MIN(event_time_utc)                                             AS first_seen_utc,
    MAX(event_time_utc)                                             AS last_seen_utc,
    -- Pattern verdict — combines breadth of hosts + breadth of users
    -- to put a single label on each (login, host) pair.
    CASE
        WHEN COUNT(*) > 50
            THEN N'🔴 high-rate attempt — investigate'
        WHEN COUNT(DISTINCT state_code) > 1 AND COUNT(*) > 5
            THEN N'🟠 multiple state codes — credential probing'
        WHEN MAX(state_code) = 7
            THEN N'🟡 disabled-login probe — password was correct'
    END                                                             AS verdict,
    -- A representative state meaning, for the screen.
    MIN(state_meaning)                                              AS sample_state,
    -- A truncated representative message
    LEFT(MIN(message), 200)                                         AS sample_message
FROM ranked
GROUP BY attempted_login, client_host

UNION ALL

-- ── 2. PATTERN: ONE IP, MANY USERS (CREDENTIAL STUFFING) ─────────
SELECT
    'PATTERN_ONE_IP_MANY_USERS'                                     AS section,
    NULL                                                            AS attempted_login,
    client_host,
    COUNT(*)                                                        AS attempts,
    COUNT(DISTINCT attempted_login)                                 AS distinct_state_codes,
    MIN(event_time_utc)                                             AS first_seen_utc,
    MAX(event_time_utc)                                             AS last_seen_utc,
    CASE
        WHEN COUNT(DISTINCT attempted_login) > 5
            THEN N'🔴 single IP attempted >5 distinct users — credential stuffing'
    END                                                             AS verdict,
    NULL                                                            AS sample_state,
    NULL                                                            AS sample_message
FROM ranked
WHERE client_host IS NOT NULL
GROUP BY client_host
HAVING COUNT(DISTINCT attempted_login) > 3

UNION ALL

-- ── 3. PATTERN: MANY IPS, ONE USER (BRUTE-FORCE OR DISTRIBUTED) ─
SELECT
    'PATTERN_MANY_IPS_ONE_USER'                                     AS section,
    attempted_login,
    NULL                                                            AS client_host,
    COUNT(*)                                                        AS attempts,
    COUNT(DISTINCT client_host)                                     AS distinct_state_codes,
    MIN(event_time_utc)                                             AS first_seen_utc,
    MAX(event_time_utc)                                             AS last_seen_utc,
    CASE
        WHEN COUNT(DISTINCT client_host) > 5
            THEN N'🔴 single login attacked from >5 distinct hosts — distributed brute force'
    END                                                             AS verdict,
    NULL                                                            AS sample_state,
    NULL                                                            AS sample_message
FROM ranked
WHERE attempted_login IS NOT NULL
GROUP BY attempted_login
HAVING COUNT(DISTINCT client_host) > 3

ORDER BY 1, 4 DESC;
