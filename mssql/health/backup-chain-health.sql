-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : backup-chain-health                             ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : health                                          ║
-- ║  Impact        : 🟢 Light  (msdb.dbo.backupset scan)              ║
-- ║  Permissions   : SELECT on msdb.dbo.backupset, .backupmediaset    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#backup-chain-health  ║
-- ║  Inspired by   : msdb backup history reference — Microsoft Learn ║
-- ║                  public catalog tables.                           ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-22                                      ║
-- ║  Level         : 🌱 Newborn  (safe to run blind, output is self-explanatory)       ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  "Do we have a recent backup of every database?" sounds like a   ║
-- ║  one-line answer. It almost never is. New databases drift in     ║
-- ║  outside the maintenance plan. Recovery model gets flipped to    ║
-- ║  SIMPLE and log backups silently stop. A backup job swallows an  ║
-- ║  error and reports green for two weeks. This script returns one  ║
-- ║  row per online database with the last full, last differential,  ║
-- ║  and last log backup, and flags the gaps that should make you    ║
-- ║  uncomfortable.                                                  ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Her online DB için son full / diff / log backup zamanlarını ve gecikme
--   uyarılarını döner. SIMPLE recovery + log backup history kombinasyonu
--   no-op olarak işaretlenir. FULL recovery'de log backup yoksa log dosyası
--   sonsuza kadar büyür — kritik flag.

WITH last_backups AS (
    SELECT
        bs.database_name,
        MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date END) AS last_full,
        MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date END) AS last_diff,
        MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date END) AS last_log
    FROM msdb.dbo.backupset AS bs
    GROUP BY bs.database_name
)
SELECT
    d.name                                                AS database_name,
    d.recovery_model_desc                                 AS recovery_model,
    d.state_desc                                          AS state,
    lb.last_full,
    DATEDIFF(HOUR, lb.last_full, SYSDATETIME())           AS last_full_age_hours,
    lb.last_diff,
    DATEDIFF(HOUR, lb.last_diff, SYSDATETIME())           AS last_diff_age_hours,
    lb.last_log,
    DATEDIFF(MINUTE, lb.last_log, SYSDATETIME())          AS last_log_age_minutes,
    CASE
        WHEN lb.last_full IS NULL
            THEN N'🔴 NO FULL BACKUP EVER — restore is impossible'
        WHEN DATEDIFF(DAY, lb.last_full, SYSDATETIME()) > 7
            THEN N'🟠 last full > 7 days — review schedule'
        WHEN d.recovery_model_desc IN (N'FULL', N'BULK_LOGGED')
             AND (lb.last_log IS NULL
                  OR DATEDIFF(MINUTE, lb.last_log, SYSDATETIME()) > 60)
            THEN N'🟠 FULL recovery model but log backup stale — log will grow'
        WHEN d.recovery_model_desc = N'SIMPLE'
             AND lb.last_log IS NOT NULL
            THEN N'ℹ️ SIMPLE recovery — log backups exist in history but are no-op now'
    END                                                   AS note
FROM sys.databases  AS d
LEFT JOIN last_backups AS lb
    ON lb.database_name = d.name
WHERE d.database_id > 4
  AND d.state_desc = N'ONLINE'
ORDER BY
    CASE
        WHEN lb.last_full IS NULL THEN 0
        WHEN DATEDIFF(DAY, lb.last_full, SYSDATETIME()) > 7 THEN 1
        ELSE 2
    END,
    d.name;
