-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : sysadmin-audit                                  ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL MI                 ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟢 Light  (catalog views only)                   ║
-- ║  Permissions   : VIEW SERVER STATE, public                       ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#sysadmin-audit       ║
-- ║  Inspired by   : sys.server_role_members reference — Microsoft   ║
-- ║                  Learn public catalog view docs.                  ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-08                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Every audit committee asks the same question first: "who has   ║
-- ║  full control of this server?" The answer must include direct   ║
-- ║  sysadmin members AND members of nested roles. This script      ║
-- ║  unwinds the recursion so you don't miss the contractor whose   ║
-- ║  AD group is in a custom role that's a member of sysadmin.      ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   sysadmin rolünün etkili üyeliğini döner: doğrudan üyeler + iç içe rol
--   üyeliğiyle ulaşılabilen herkes. Azure SQL Database (single) sürümünde
--   sunucu seviyesinde rol kavramı yok; o edition'da bilgilendirme satırı
--   döner. Disabled login'ler audit'te hâlâ sayılır — flag'lenir.
--
-- Returns the effective sysadmin membership: direct grants plus everyone
-- reachable through nested role membership. Each row also flags whether
-- the principal is currently disabled (a common mistake — a disabled
-- login still counts in audits and still owns its objects).
--
-- Production note:
--   On Azure SQL Managed Instance this runs but only over the MI's own
--   logins. On Azure SQL Database (single), the server-level role concept
--   doesn't exist; this script is silent on that edition by design.

IF CAST(SERVERPROPERTY('EngineEdition') AS INT) = 5
BEGIN
    SELECT
        N'INFO' AS section,
        N'sysadmin role does not exist on Azure SQL Database (single)' AS message;
    RETURN;
END;

WITH role_recursion AS (
    -- Anchor: direct members of sysadmin.
    SELECT
        rm.member_principal_id      AS principal_id,
        CAST(N'sysadmin' AS sysname) AS via_role,
        0                            AS depth
    FROM sys.server_role_members AS rm
    JOIN sys.server_principals    AS r
        ON r.principal_id = rm.role_principal_id
        AND r.name = N'sysadmin'

    UNION ALL

    -- Recurse: members of any role that is itself in our growing set.
    SELECT
        rm.member_principal_id,
        CAST(p.name AS sysname),
        rr.depth + 1
    FROM role_recursion          AS rr
    JOIN sys.server_role_members AS rm
        ON rm.role_principal_id = rr.principal_id
    JOIN sys.server_principals   AS p
        ON p.principal_id = rr.principal_id
)
SELECT DISTINCT
    sp.name                                                AS principal_name,
    sp.type_desc                                           AS principal_type,
    rr.via_role                                            AS reached_via,
    rr.depth                                               AS nesting_depth,
    sp.is_disabled,
    sp.create_date,
    sp.modify_date,
    CASE
        WHEN sp.is_disabled = 1
            THEN N'disabled — still has rights if re-enabled, audit accordingly'
        WHEN sp.type IN ('U', 'G')
            THEN N'AD principal — check group membership in directory'
    END                                                    AS note
FROM role_recursion         AS rr
JOIN sys.server_principals  AS sp
    ON sp.principal_id = rr.principal_id
WHERE sp.type NOT IN ('R')   -- exclude role-only rows
ORDER BY rr.depth, sp.name;
