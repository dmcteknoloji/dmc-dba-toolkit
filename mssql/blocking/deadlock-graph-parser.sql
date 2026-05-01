-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : deadlock-graph-parser                           ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : blocking                                        ║
-- ║  Impact        : 🟡 Medium  (reads system_health XE ring buffer)  ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mssql-deadlock-graph-parser ║
-- ║  Inspired by   : system_health Extended Events session — public  ║
-- ║                  Microsoft Learn reference. The parser approach   ║
-- ║                  draws on Jonathan Kehayias's SQLskills public    ║
-- ║                  XE deadlock posts; technique credited, code      ║
-- ║                  original.                                        ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-05-01                                      ║
-- ║  Level         : 🦅 Expert   (XML shredding + XE internals + interpretation) ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: Trace flag 1222 is gone. The system_health Extended Events
--       session is already running on every modern SQL Server and
--       captures every deadlock graph as XML in a ring buffer. This
--       script shreds that XML into a tabular form: per-deadlock
--       timestamp, victim and survivor process IDs, their query
--       texts, the locked resources, and the wait modes — without
--       any external trace tool, without enabling anything extra.
--   TR: Trace flag 1222'ye veda. system_health Extended Events
--       oturumu modern her SQL Server'da zaten çalışıyor ve her
--       deadlock'un XML graph'ini ring buffer'a düşürüyor. Bu script
--       o XML'i tablo formuna döker: deadlock başına timestamp,
--       kurban ve hayatta kalan process'lerin ID'si, sorgu metinleri,
--       kilitlenmiş kaynaklar ve wait mode'lar — harici trace aracı
--       yok, ekstra bir şey enable etmeye gerek yok.
--
-- The XML shape / XML şekli:
--   The deadlock graph XML has two top-level groups:
--     <process-list>  — every session involved
--     <resource-list> — every locked resource
--   Inside each <process>, the <executionStack>/<frame> nodes name
--   the proc and the inputbuf is the actual SQL text.
--
-- Production note / Üretim notu:
--   The system_health ring buffer is in-memory and rotates; old
--   deadlocks fall out. On a busy server the window can be only
--   minutes. For long-term retention, persist the rows produced by
--   this script into a target table on a schedule.

-- ── 1. EXTRACT DEADLOCK XML EVENTS ─────────────────────────────────
-- Read the system_health session's XEL file via the file target;
-- ring buffer is faster but sometimes missing on Azure SQL MI.
WITH ring_buffer AS (
    SELECT CAST(target_data AS XML) AS xml_data
    FROM sys.dm_xe_session_targets   AS t
    JOIN sys.dm_xe_sessions          AS s
        ON s.address = t.event_session_address
    WHERE s.name = N'system_health'
      AND t.target_name = N'ring_buffer'
),
events AS (
    SELECT
        xev.value('(@timestamp)[1]', 'datetime2(3)')                AS event_time_utc,
        xev.query('(./data/value/deadlock)[1]')                     AS deadlock_xml
    FROM ring_buffer
    CROSS APPLY xml_data.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]')
                                                                   AS x(xev)
)
SELECT TOP (20)
    e.event_time_utc                                                AS deadlock_time_utc,

    -- The victim process — the one SQL Server killed.
    e.deadlock_xml.value(
        '(/deadlock/victim-list/victimProcess/@id)[1]', 'nvarchar(50)')
                                                                   AS victim_process_id,

    -- The number of processes involved.
    e.deadlock_xml.value(
        'count(/deadlock/process-list/process)', 'int')             AS process_count,

    -- The number of resources involved.
    e.deadlock_xml.value(
        'count(/deadlock/resource-list/*)', 'int')                  AS resource_count,

    -- The deadlock priority of the victim — high values = chosen LAST
    -- by the deadlock monitor (the survivor was higher priority).
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@priority)[1]',
        'int')                                                      AS victim_priority,

    -- Database where the victim was running (handy when many DBs
    -- coexist on one instance).
    DB_NAME(
        e.deadlock_xml.value(
            '(/deadlock/process-list/process[@id=
                  /deadlock/victim-list/victimProcess/@id]/@currentdb)[1]',
            'int'))                                                 AS victim_database,

    -- The waitresource the victim was after — typically a KEY: 7:1234...
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@waitresource)[1]',
        'nvarchar(256)')                                            AS victim_wait_resource,

    -- The lock mode the victim wanted (X, U, IS, IX, S...).
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@lockMode)[1]',
        'nvarchar(20)')                                             AS victim_lock_mode,

    -- The transaction name (if BEGIN TRAN named one) — useful for
    -- correlating to the application's transaction labels.
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@transactionname)[1]',
        'nvarchar(128)')                                            AS victim_transaction,

    -- Client/host context for the victim
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@hostname)[1]',
        'nvarchar(128)')                                            AS victim_host,
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@clientapp)[1]',
        'nvarchar(256)')                                            AS victim_clientapp,
    e.deadlock_xml.value(
        '(/deadlock/process-list/process[@id=
              /deadlock/victim-list/victimProcess/@id]/@loginname)[1]',
        'nvarchar(128)')                                            AS victim_login,

    -- The actual T-SQL the victim was executing — the inputbuf.
    LEFT(
        e.deadlock_xml.value(
            '(/deadlock/process-list/process[@id=
                  /deadlock/victim-list/victimProcess/@id]/inputbuf)[1]',
            'nvarchar(max)'),
        4000)                                                       AS victim_inputbuf,

    -- The full deadlock XML — drop into SSMS as a deadlock graph
    -- visualisation, or feed to a parser of your own.
    e.deadlock_xml                                                  AS deadlock_xml
FROM events AS e
ORDER BY e.event_time_utc DESC;
