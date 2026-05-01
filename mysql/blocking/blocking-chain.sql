-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : blocking-chain                                  ║
-- ║  Engine        : MySQL 8.0+ │ Aurora MySQL │ Percona Server 8.0+ ║
-- ║  Category      : blocking                                        ║
-- ║  Impact        : 🟢 Light  (performance_schema + sys schema)      ║
-- ║  Permissions   : SELECT on performance_schema.*, sys.*           ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#mysql-blocking-chain ║
-- ║  Inspired by   : sys.innodb_lock_waits — MySQL Reference Manual  ║
-- ║  Maintainer    : Çağlar Özenç — DMC Bilgi Teknolojileri          ║
-- ║  Last updated  : 2025-12-19                                      ║
-- ║  Level         : 🌳 Middle   (production-grade, assumes DBA familiarity)           ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
--
-- 🇹🇷 Türkçe özet:
--   sys.innodb_lock_waits üzerinden "kim kimi bekliyor?" sorusunun anlık
--   cevabı (MySQL 8.0+). 5.7'de information_schema.innodb_lock_waits
--   farklı kolon adlarıyla var — bu script v2.1 backlog. Waiter ve blocker'ın
--   host/user/query metni processlist'ten join'lenir.
--
-- Returns who is waiting on whom right now using performance_schema's
-- data_lock_waits + data_locks views (MySQL 8.0+). On 5.7, the
-- equivalent information_schema.innodb_lock_waits view exists but with
-- different column names — kept on the v2.1 backlog as a separate
-- script.
--
-- The sys.innodb_lock_waits view is a convenient pre-shaped join of
-- data_lock_waits with the relevant data_locks rows; we use it directly
-- and add session metadata from processlist for context.

SELECT
    ilw.wait_age_secs                                              AS wait_age_secs,
    ilw.locked_table_schema                                        AS schema_name,
    ilw.locked_table_name                                          AS table_name,
    ilw.locked_index                                               AS index_name,
    ilw.locked_type                                                AS lock_type,
    ilw.waiting_pid                                                AS waiting_pid,
    ilw.waiting_query                                              AS waiting_query,
    ilw.waiting_lock_mode                                          AS waiting_lock_mode,
    ilw.blocking_pid                                               AS blocking_pid,
    ilw.blocking_query                                             AS blocking_query,
    ilw.blocking_lock_mode                                         AS blocking_lock_mode,
    pl_w.HOST                                                      AS waiting_host,
    pl_w.USER                                                      AS waiting_user,
    pl_b.HOST                                                      AS blocking_host,
    pl_b.USER                                                      AS blocking_user
FROM sys.innodb_lock_waits AS ilw
LEFT JOIN performance_schema.processlist AS pl_w
    ON pl_w.ID = ilw.waiting_pid
LEFT JOIN performance_schema.processlist AS pl_b
    ON pl_b.ID = ilw.blocking_pid
ORDER BY ilw.wait_age_secs DESC;
