-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : tls-and-transport-security                     ║
-- ║  Engine        : MySQL 8.0+ │ Percona Server │ Aurora MySQL     ║
-- ║  Category      : security                                       ║
-- ║  Impact        : 🟢 Light  (global_variables + mysql.user)       ║
-- ║  Permissions   : SELECT on performance_schema, mysql.user        ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-tls-and-transport-security ║
-- ║  Inspired by   : require_secure_transport / ssl_type reference — ║
-- ║                  MySQL public documentation.                     ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (is the wire actually encrypted?)   ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  A server can have TLS available and still accept every          ║
-- ║  connection in plaintext, because nothing requires it. This      ║
-- ║  reads the transport posture in one pass: is TLS compiled in,    ║
-- ║  what TLS versions are offered, is require_secure_transport on,   ║
-- ║  and — the part people forget — how many accounts have no SSL    ║
-- ║  requirement at all (ssl_type empty), so they can connect        ║
-- ║  unencrypted regardless of the global flag.                      ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Sunucu TLS destekliyor olsa bile, hiçbir şey zorunlu kılmıyorsa her
--   bağlantıyı düz metin kabul edebilir. Bu script taşıma katmanı duruşunu
--   tek bakışta verir: TLS derlenmiş mi, hangi sürümler sunuluyor,
--   require_secure_transport açık mı ve kaç hesabın hiç SSL zorunluluğu yok
--   (ssl_type boş). Salt-okunur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 alerts when require_secure_transport drifts off or a new
--   account without an SSL requirement appears — see https://github.com/dmcteknoloji.

SELECT
    'GLOBAL'                                                       AS section,
    CONVERT(v.VARIABLE_NAME USING utf8mb4)                         AS item,
    CONVERT(v.VARIABLE_VALUE USING utf8mb4)                        AS value,
    CASE v.VARIABLE_NAME
        WHEN 'have_ssl' THEN
            CASE WHEN v.VARIABLE_VALUE = 'YES' THEN '🟢 TLS compiled in'
                 ELSE '🔴 TLS not available' END
        WHEN 'require_secure_transport' THEN
            CASE WHEN v.VARIABLE_VALUE = 'ON' THEN '🟢 plaintext connections refused'
                 ELSE '🟠 plaintext allowed — set require_secure_transport=ON' END
        WHEN 'tls_version' THEN
            CASE WHEN v.VARIABLE_VALUE LIKE '%TLSv1.3%' THEN '🟢 TLS 1.2/1.3 offered'
                 WHEN v.VARIABLE_VALUE LIKE '%TLSv1.1%' OR v.VARIABLE_VALUE LIKE '%TLSv1,%'
                      OR v.VARIABLE_VALUE = 'TLSv1' THEN '🟠 legacy TLS offered — drop to 1.2+'
                 ELSE '🟢 modern TLS floor' END
        ELSE ''
    END                                                           AS verdict
FROM performance_schema.global_variables AS v
WHERE v.VARIABLE_NAME IN ('have_ssl', 'have_openssl', 'require_secure_transport', 'tls_version')

UNION ALL

SELECT
    'ACCOUNTS'                                                     AS section,
    CONVERT('accounts_without_ssl_requirement' USING utf8mb4)     AS item,
    CONVERT(CAST(COUNT(*) AS CHAR) USING utf8mb4)                 AS value,
    CASE
        WHEN COUNT(*) > 0
            THEN CONCAT('🟠 ', CAST(COUNT(*) AS CHAR),
                        ' account(s) with empty ssl_type — can connect unencrypted')
        ELSE '🟢 every account requires SSL'
    END                                                           AS verdict
FROM mysql.user
WHERE ssl_type = ''
  AND account_locked = 'N'
  AND User NOT IN ('mysql.session', 'mysql.sys', 'mysql.infoschema')

ORDER BY section, item;
