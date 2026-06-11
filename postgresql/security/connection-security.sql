-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : connection-security                            ║
-- ║  Engine        : PostgreSQL 12+ │ Aurora PG │ Cloud SQL PG      ║
-- ║  Category      : security                                       ║
-- ║  Impact        : 🟢 Light  (pg_settings + pg_stat_ssl)           ║
-- ║  Permissions   : SELECT on pg_settings, pg_stat_ssl (monitor)    ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#pg-connection-security ║
-- ║  Inspired by   : pg_stat_ssl and SSL configuration reference —  ║
-- ║                  PostgreSQL public documentation.                ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2026-06-11                                      ║
-- ║  Level         : 🌳 Middle  (how clients actually connect)      ║
-- ║  Version       : 1.0.0                                          ║
-- ║  License       : MIT                                            ║
-- ║                                                                  ║
-- ║  Why this exists:                                                ║
-- ║  Roles and grants describe who can connect; this describes how   ║
-- ║  they connect. Is TLS on? Are passwords stored with scram or     ║
-- ║  still md5? Is the minimum TLS version sane? And — the question  ║
-- ║  no setting answers — how many sessions right now are actually   ║
-- ║  encrypted versus in the clear? This pulls the security-relevant ║
-- ║  settings and the live SSL usage into one posture read.          ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   Bağlantıların nasıl kurulduğunu denetler: TLS açık mı, parolalar scram
--   ile mi yoksa hâlâ md5 ile mi saklanıyor, minimum TLS sürümü makul mü ve
--   şu an kaç oturum gerçekten şifreli? Güvenlikle ilgili ayarları ve canlı
--   SSL kullanımını tek tabloda toplar. Salt-okunur.
--
-- Beyond this script / Bunun ötesinde:
--   Sentinel DB 360 alerts when an unencrypted session appears or
--   password_encryption drifts off scram — see https://github.com/dmcteknoloji.

SELECT
    'SETTING'                                                     AS section,
    s.name                                                        AS item,
    s.setting                                                     AS value,
    CASE s.name
        WHEN 'ssl' THEN
            CASE WHEN s.setting = 'on' THEN '🟢 TLS available'
                 ELSE '🔴 TLS disabled — connections can be in the clear' END
        WHEN 'password_encryption' THEN
            CASE WHEN s.setting LIKE 'scram%' THEN '🟢 scram-sha-256'
                 ELSE '🟠 md5 — migrate to scram-sha-256' END
        WHEN 'log_connections' THEN
            CASE WHEN s.setting = 'on' THEN '🟢 connections logged'
                 ELSE '🟡 connection logging off — no audit trail of logins' END
        WHEN 'log_disconnections' THEN
            CASE WHEN s.setting = 'on' THEN '🟢 disconnections logged'
                 ELSE '🟡 disconnection logging off' END
        WHEN 'ssl_min_protocol_version' THEN
            CASE WHEN s.setting IN ('TLSv1.2', 'TLSv1.3') THEN '🟢 modern TLS floor'
                 ELSE '🟠 raise ssl_min_protocol_version to TLSv1.2+' END
        ELSE ''
    END                                                           AS verdict
FROM pg_settings AS s
WHERE s.name IN ('ssl', 'password_encryption', 'log_connections',
                 'log_disconnections', 'ssl_min_protocol_version')

UNION ALL

SELECT
    'CONNECTIONS'                                                 AS section,
    'encrypted_sessions'                                          AS item,
    count(*) FILTER (WHERE ssl)::text || ' of ' || count(*)::text AS value,
    CASE
        WHEN count(*) FILTER (WHERE NOT ssl) > 0
            THEN '🟠 ' || count(*) FILTER (WHERE NOT ssl)::text
                 || ' session(s) not using TLS — check pg_hba.conf'
        ELSE '🟢 all current sessions are encrypted'
    END                                                           AS verdict
FROM pg_stat_ssl

ORDER BY section, item;
