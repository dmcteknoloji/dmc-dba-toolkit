-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : tde-status                                      ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟢 Light  (catalog + DMV)                        ║
-- ║  Permissions   : VIEW SERVER STATE, VIEW ANY DEFINITION          ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#tde-status           ║
-- ║  Inspired by   : sys.dm_database_encryption_keys — Microsoft     ║
-- ║                  Learn public reference.                          ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-12                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  TDE encryption_state has eight values and most people only      ║
-- ║  remember "3 = encrypted". A database stuck at state 2 (in       ║
-- ║  progress) for hours is a problem. State 5 means decryption is   ║
-- ║  running — usually unintended. This script translates the        ║
-- ║  numeric state into plain English alongside key health.          ║
-- ╚══════════════════════════════════════════════════════════════════╝

SELECT
    DB_NAME(dek.database_id)                              AS database_name,
    dek.encryption_state,
    CASE dek.encryption_state
        WHEN 0 THEN N'no database encryption key present'
        WHEN 1 THEN N'unencrypted'
        WHEN 2 THEN N'encryption in progress'
        WHEN 3 THEN N'encrypted'
        WHEN 4 THEN N'key change in progress'
        WHEN 5 THEN N'decryption in progress'
        WHEN 6 THEN N'protection change in progress'
        WHEN 7 THEN N'unencrypted (read-only filegroup pending)'
        ELSE        N'unknown'
    END                                                   AS state_description,
    dek.key_algorithm,
    dek.key_length                                        AS key_length_bits,
    dek.encryptor_type,
    -- The thumbprint of the cert/asymmetric key protecting the DEK.
    -- If you rotate the certificate without re-encrypting the DEK,
    -- this is what links them. Always backup any cert whose thumbprint
    -- shows up in this column — losing it means losing the database.
    dek.encryptor_thumbprint,
    dek.create_date,
    dek.regenerate_date,
    dek.set_date,
    dek.opened_date,
    CASE
        WHEN dek.encryption_state = 2
             AND DATEDIFF(HOUR, dek.set_date, SYSUTCDATETIME()) > 24
            THEN N'in-progress for >24h — likely stuck, investigate'
        WHEN dek.encryption_state = 5
            THEN N'DECRYPTION running — verify this is intentional'
        WHEN dek.encryption_state = 0
            THEN N'no DEK at all — database not enrolled in TDE'
    END                                                   AS note
FROM sys.dm_database_encryption_keys AS dek
ORDER BY DB_NAME(dek.database_id);

-- Server certificate inventory (skipped on Azure SQL DB single).
IF CAST(SERVERPROPERTY('EngineEdition') AS INT) <> 5
BEGIN
    SELECT
        c.name                                            AS cert_name,
        c.subject,
        c.thumbprint,
        c.issuer_name,
        c.start_date,
        c.expiry_date,
        DATEDIFF(DAY, SYSUTCDATETIME(), c.expiry_date)    AS days_to_expiry,
        c.pvt_key_encryption_type_desc,
        CASE
            WHEN c.expiry_date < SYSUTCDATETIME()
                THEN N'EXPIRED — rotate immediately'
            WHEN DATEDIFF(DAY, SYSUTCDATETIME(), c.expiry_date) < 90
                THEN N'expires within 90 days — plan rotation'
        END                                               AS note
    FROM master.sys.certificates AS c
    ORDER BY c.expiry_date;
END;
