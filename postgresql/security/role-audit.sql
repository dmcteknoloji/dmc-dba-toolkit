-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : role-audit                                      ║
-- ║  Engine        : PostgreSQL 13+ │ Aurora PG │ Cloud SQL PG       ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟢 Light  (catalog only)                         ║
-- ║  Permissions   : standard read on pg_catalog.pg_authid /         ║
-- ║                  pg_roles. Some columns require superuser or     ║
-- ║                  pg_read_server_files; the script tolerates      ║
-- ║                  whichever subset you have.                      ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-role-audit        ║
-- ║  Inspired by   : PostgreSQL official docs — Role Membership      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-14                                      ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  When the security team asks "who can do what?" on a Postgres   ║
-- ║  cluster, the honest answer involves: who is a SUPERUSER, who   ║
-- ║  has CREATEROLE (effective superuser via privilege escalation), ║
-- ║  who can BYPASSRLS, and which roles inherit those rights        ║
-- ║  through nested membership. This script returns all of those in ║
-- ║  one pass and unwinds the membership graph.                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. ROLES WITH ELEVATED ATTRIBUTES ───────────────────────────────
SELECT
    'ELEVATED'                                          AS section,
    r.rolname                                           AS role_name,
    r.rolsuper                                          AS is_superuser,
    r.rolcreaterole                                     AS can_create_role,
    r.rolcreatedb                                       AS can_create_db,
    r.rolbypassrls                                      AS bypasses_rls,
    r.rolreplication                                    AS can_replicate,
    r.rolcanlogin                                       AS can_login,
    r.rolvaliduntil                                     AS valid_until,
    CASE
        WHEN r.rolsuper
            THEN '🔴 SUPERUSER — full control of the cluster'
        WHEN r.rolcreaterole
            THEN '🟠 CREATEROLE — can grant arbitrary memberships, effectively superuser-adjacent'
        WHEN r.rolbypassrls
            THEN '🟠 BYPASSRLS — ignores row-level security policies'
        WHEN r.rolreplication
            THEN '🟡 REPLICATION — can stream the entire cluster contents'
        WHEN r.rolcreatedb
            THEN '🟡 CREATEDB — can create databases (rarely justified for app accounts)'
    END                                                 AS note
FROM pg_roles AS r
WHERE r.rolsuper OR r.rolcreaterole OR r.rolbypassrls
   OR r.rolreplication OR r.rolcreatedb
ORDER BY r.rolsuper DESC, r.rolname;

-- ── 2. EFFECTIVE SUPERUSER VIA NESTED MEMBERSHIP ────────────────────
WITH RECURSIVE membership(role_oid, member_oid, depth) AS (
    SELECT roleid, member, 1
    FROM pg_auth_members

    UNION ALL

    SELECT m.role_oid, am.member, m.depth + 1
    FROM membership            AS m
    JOIN pg_auth_members       AS am ON am.roleid = m.member_oid
    WHERE m.depth < 10
)
SELECT DISTINCT
    'NESTED'                                            AS section,
    leaf.rolname                                        AS effective_user,
    grant_role.rolname                                  AS reaches_role,
    m.depth                                             AS nesting_depth,
    CASE
        WHEN grant_role.rolsuper       THEN 'effectively SUPERUSER'
        WHEN grant_role.rolcreaterole  THEN 'effectively CREATEROLE'
        WHEN grant_role.rolbypassrls   THEN 'effectively BYPASSRLS'
    END                                                 AS effective_attribute
FROM membership          AS m
JOIN pg_roles            AS leaf       ON leaf.oid = m.member_oid
JOIN pg_roles            AS grant_role ON grant_role.oid = m.role_oid
WHERE leaf.rolcanlogin
  AND NOT leaf.rolsuper                  -- skip already-explicit superusers
  AND (grant_role.rolsuper OR grant_role.rolcreaterole OR grant_role.rolbypassrls)
ORDER BY effective_user, nesting_depth;
