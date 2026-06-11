-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : schema-privilege-grants                        ║
-- ║  Engine        : MySQL 8.0+ │ Percona Server │ Aurora MySQL     ║
-- ║  Category      : security                                       ║
-- ║  Impact        : 🟢 Light  (information_schema scan)             ║
-- ║  Permissions   : SELECT on information_schema privilege views    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-schema-privilege-grants ║
-- ║  Inspired by   : information_schema SCHEMA/TABLE_PRIVILEGES —    ║
-- ║                  MySQL public documentation.                     ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (where access actually lands)       ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  user-audit covers global privileges and the account inventory.  ║
-- ║  But most real access is scoped — granted on a specific schema   ║
-- ║  or table. That is exactly where over-broad rights hide: a       ║
-- ║  reporting user with ALL on a write schema, a stale app account  ║
-- ║  that can DROP, a grant left WITH GRANT OPTION. This lists the    ║
-- ║  schema and table level grants in one pass and floats the        ║
-- ║  re-grantable and write-heavy ones to the top.                   ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   user-audit global yetkileri kapsar; bu script şema/tablo seviyesindeki
--   yetkileri (gerçek erişimin indiği yer) listeler. WITH GRANT OPTION ve
--   yazma yetkileri (INSERT/UPDATE/DELETE/DROP/ALL) en üstte işaretlenir.
--   Eski/test hesaplarının fazla geniş yetkilerini ortaya çıkarır. Salt-okunur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 diffs scoped grants over time and flags any new
--   re-grantable or write privilege — see https://github.com/dmcteknoloji.

SELECT
    'SCHEMA_GRANT'                                                 AS section,
    sp.GRANTEE                                                     AS grantee,
    sp.TABLE_SCHEMA                                                AS schema_name,
    '*'                                                            AS object_name,
    sp.PRIVILEGE_TYPE                                              AS privilege,
    sp.IS_GRANTABLE                                                AS is_grantable,
    CASE
        WHEN sp.IS_GRANTABLE = 'YES'
            THEN '🟠 grantee can re-grant this (WITH GRANT OPTION)'
        WHEN sp.PRIVILEGE_TYPE IN ('INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE')
            THEN '🟡 write/DDL privilege at schema scope'
        ELSE '🟢 scoped grant'
    END                                                            AS verdict
FROM information_schema.SCHEMA_PRIVILEGES AS sp
WHERE sp.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')

UNION ALL

SELECT
    'TABLE_GRANT'                                                  AS section,
    tp.GRANTEE                                                     AS grantee,
    tp.TABLE_SCHEMA                                                AS schema_name,
    tp.TABLE_NAME                                                  AS object_name,
    tp.PRIVILEGE_TYPE                                              AS privilege,
    tp.IS_GRANTABLE                                                AS is_grantable,
    CASE
        WHEN tp.IS_GRANTABLE = 'YES'
            THEN '🟠 grantee can re-grant this (WITH GRANT OPTION)'
        WHEN tp.PRIVILEGE_TYPE IN ('INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE')
            THEN '🟡 write/DDL privilege at table scope'
        ELSE '🟢 scoped grant'
    END                                                            AS verdict
FROM information_schema.TABLE_PRIVILEGES AS tp
WHERE tp.TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')

ORDER BY is_grantable DESC, grantee, schema_name, object_name;
