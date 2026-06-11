-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : object-privilege-grants                        ║
-- ║  Engine        : PostgreSQL 12+ │ Aurora PG │ Cloud SQL PG      ║
-- ║  Category      : security                                       ║
-- ║  Impact        : 🟢 Light  (information_schema scan)             ║
-- ║  Permissions   : SELECT on information_schema (superuser sees all) ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-object-privilege-grants ║
-- ║  Inspired by   : information_schema.table_privileges reference — ║
-- ║                  PostgreSQL public documentation.                ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (PUBLIC grants are the quiet risk)   ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  role-audit answers "who is powerful?". This answers the other   ║
-- ║  half: "what can they reach?". Object-level grants are where     ║
-- ║  access quietly widens — a GRANT … TO PUBLIC on one table, a     ║
-- ║  forgotten WITH GRANT OPTION, a service role that accumulated    ║
-- ║  privileges nobody tracks. This lists table and schema grants    ║
-- ║  on user objects, puts PUBLIC and grantable rights at the top,   ║
-- ║  and ignores the system catalogs so the signal isn't buried.     ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   role-audit "kim güçlü?"yü, bu script "neye erişebiliyor?"yu yanıtlar.
--   Kullanıcı tabloları ve şemaları üzerindeki yetkileri listeler; PUBLIC'e
--   verilen ve WITH GRANT OPTION içeren yetkiler en üstte (🔴/🟠) işaretlenir.
--   Sistem katalogları hariç tutulur. Salt-okunur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 snapshots object grants over time and alerts when a new
--   PUBLIC or grantable privilege appears — see https://github.com/dmcteknoloji.

SELECT
    'TABLE_GRANT'                                                 AS section,
    g.table_schema                                               AS schema_name,
    g.table_name                                                 AS object_name,
    g.grantee                                                    AS grantee,
    g.privilege_type                                             AS privilege,
    g.is_grantable                                               AS is_grantable,
    g.grantor                                                    AS granted_by,
    CASE
        WHEN g.grantee = 'PUBLIC'
            THEN '🔴 granted to PUBLIC — every role, including future ones, has this'
        WHEN g.is_grantable = 'YES'
            THEN '🟠 grantee can re-grant this privilege (WITH GRANT OPTION)'
        ELSE '🟢 scoped grant'
    END                                                          AS verdict
FROM information_schema.role_table_grants AS g
WHERE g.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY
    CASE WHEN g.grantee = 'PUBLIC' THEN 0
         WHEN g.is_grantable = 'YES' THEN 1
         ELSE 2 END,
    g.table_schema, g.table_name, g.grantee;
