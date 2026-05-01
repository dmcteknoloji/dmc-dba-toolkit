-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : user-audit                                      ║
-- ║  Engine        : MySQL 5.7+ │ MySQL 8.0/8.4 │ Aurora MySQL │ PS  ║
-- ║  Category      : security                                        ║
-- ║  Impact        : 🟢 Light  (mysql schema + INFORMATION_SCHEMA)    ║
-- ║  Permissions   : SELECT on mysql.user; SELECT_CATALOG_ROLE-equiv ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-user-audit     ║
-- ║  Inspired by   : MySQL Reference Manual — Account Management,    ║
-- ║                  mysql.user table reference.                      ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-04-13                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- Why this exists / Neden var:
--   EN: A clean MySQL inventory has tight host scoping, no ANY-host
--       wildcards on privileged accounts, no expired or never-rotated
--       passwords, and no test/legacy users still holding GRANT OPTION.
--       This script puts all of that in one screen — and flags the
--       three patterns auditors always ask about: SUPER, GRANT OPTION,
--       and accounts authenticated with native vs caching_sha2.
--   TR: Sağlıklı bir MySQL hesap envanteri sıkı host kısıtlaması,
--       imtiyazlı hesaplarda '%' wildcard'ı bulunmaması, süresi geçmiş
--       veya hiç değişmemiş parolaların olmaması ve hâlâ GRANT OPTION
--       tutan eski/test kullanıcıların kalmaması demektir. Bu script
--       hepsini tek ekranda toplar — denetçilerin daima sorduğu üç
--       paterni işaretler: SUPER, GRANT OPTION ve native vs
--       caching_sha2 kimlik doğrulama.
--
-- Production note / Üretim notu:
--   EN: On MySQL 8.0+, SUPER is partially deprecated in favour of
--       dynamic privileges (e.g. CONNECTION_ADMIN, ROLE_ADMIN). The
--       global_grants check below covers both worlds.
--   TR: MySQL 8.0+ ile SUPER kısmen kullanımdan kaldırıldı; yerine
--       dynamic privileges geldi (CONNECTION_ADMIN, ROLE_ADMIN vb).
--       Aşağıdaki global_grants kontrolü her iki dünyayı da kapsar.

-- ── 1. ELEVATED ACCOUNTS ────────────────────────────────────────────
SELECT
    'ELEVATED'                                                        AS section,
    u.User                                                            AS user_name,
    u.Host                                                            AS host_pattern,
    u.account_locked                                                  AS account_locked,
    u.password_expired                                                AS password_expired,
    u.password_last_changed,
    DATEDIFF(NOW(), u.password_last_changed)                          AS pwd_age_days,
    u.plugin                                                          AS auth_plugin,
    -- Static SUPER (5.7 + carry-over in 8.0)
    u.Super_priv                                                      AS has_super,
    -- Coverage of the most common high-impact static privileges
    u.Grant_priv                                                      AS has_grant_option,
    u.Reload_priv                                                     AS has_reload,
    u.Shutdown_priv                                                   AS has_shutdown,
    u.Process_priv                                                    AS has_process,
    u.File_priv                                                       AS has_file,
    -- Verdict / Karar
    CONCAT_WS(' | ',
        CASE WHEN u.Host = '%'        THEN '🔴 host="%" — connectable from anywhere' END,
        CASE WHEN u.Super_priv = 'Y'  THEN '🔴 SUPER privilege' END,
        CASE WHEN u.Grant_priv = 'Y'  THEN '🟠 GRANT OPTION — can elevate others' END,
        CASE WHEN u.password_expired = 'Y'
                                       THEN '🟠 password expired' END,
        CASE WHEN u.account_locked  = 'Y'
                                       THEN 'ℹ️ account locked (still inventoried)' END,
        CASE WHEN DATEDIFF(NOW(), u.password_last_changed) > 365
                                       THEN '🟠 password not rotated for >365 days' END,
        CASE WHEN u.plugin = 'mysql_native_password'
                                       THEN '🟡 mysql_native_password — consider caching_sha2_password' END
    )                                                                 AS note
FROM mysql.user AS u
WHERE u.Super_priv = 'Y'
   OR u.Grant_priv = 'Y'
   OR u.Reload_priv = 'Y'
   OR u.Shutdown_priv = 'Y'
   OR u.File_priv = 'Y'
   OR u.Host = '%'
ORDER BY (u.Super_priv='Y') DESC, (u.Grant_priv='Y') DESC, u.User;

-- ── 2. DYNAMIC PRIVILEGES (8.0+) — "the new SUPER" ─────────────────
-- These dynamic privileges replaced parts of SUPER. A non-DBA holding
-- BINLOG_ADMIN, CONNECTION_ADMIN, ROLE_ADMIN, REPLICATION_SLAVE_ADMIN
-- or SYSTEM_VARIABLES_ADMIN is just as dangerous as the old SUPER.
SELECT
    'DYNAMIC_PRIVS'                                                   AS section,
    USER                                                              AS user_name,
    HOST                                                              AS host_pattern,
    PRIV                                                              AS privilege,
    WITH_GRANT_OPTION                                                 AS with_grant_option
FROM mysql.global_grants
WHERE PRIV IN (
    'SYSTEM_USER',
    'BINLOG_ADMIN', 'BINLOG_ENCRYPTION_ADMIN',
    'CONNECTION_ADMIN', 'ENCRYPTION_KEY_ADMIN',
    'GROUP_REPLICATION_ADMIN',
    'PERSIST_RO_VARIABLES_ADMIN',
    'REPLICATION_APPLIER', 'REPLICATION_SLAVE_ADMIN',
    'RESOURCE_GROUP_ADMIN', 'RESOURCE_GROUP_USER',
    'ROLE_ADMIN',
    'SERVICE_CONNECTION_ADMIN',
    'SET_USER_ID',
    'SHOW_ROUTINE',
    'SYSTEM_VARIABLES_ADMIN',
    'TABLE_ENCRYPTION_ADMIN',
    'XA_RECOVER_ADMIN'
)
ORDER BY USER, HOST, PRIV;

-- ── 3. ACCOUNTS WITH WILDCARD HOSTS BUT NO EXPLICIT IP RESTRICT ────
SELECT
    'WILDCARD_HOSTS'                                                  AS section,
    u.User                                                            AS user_name,
    u.Host                                                            AS host_pattern,
    u.plugin                                                          AS auth_plugin,
    -- Verdict / Karar
    CASE
        WHEN u.Host = '%' AND u.Super_priv = 'Y'
            THEN '🔴 SUPER + host % — fix immediately'
        WHEN u.Host = '%'
            THEN '🟠 host=% — anyone with credentials can connect'
        WHEN u.Host LIKE '%\\%%' ESCAPE '\\'
            THEN '🟡 host wildcard — review subnet scope'
        ELSE NULL
    END                                                               AS note
FROM mysql.user AS u
WHERE u.Host = '%' OR u.Host LIKE '%\\%%' ESCAPE '\\'
ORDER BY (u.Host = '%') DESC, u.User;
