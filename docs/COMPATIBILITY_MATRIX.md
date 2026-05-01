# Compatibility Matrix

Authoritative compatibility data for every script in the toolkit. Updated on every release.

Legend:
- ✅ Tested and supported.
- ⚠️ Partial — some columns or sections behave differently. See script header for the specifics.
- ❌ Not supported on this engine/edition.
- ❓ Untested. Community confirmation welcome.

---

## SQL Server

| Script | 2016 | 2017 | 2019 | 2022 | Azure SQL DB | Azure SQL MI |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `mssql/performance/top-cpu-queries` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/performance/wait-stats-summary` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/performance/missing-indexes` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/blocking/blocking-chain` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/storage/db-file-growth` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| `mssql/health/instance-overview` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| `mssql/security/sysadmin-audit` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/security/tde-status` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| `mssql/security/orphaned-users` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/health/error-log-last-24h` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/health/backup-chain-health` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/ha/ag-status` | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ |
| `mssql/monitoring/health-snapshot` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| `mssql/monitoring/query-throughput-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/monitoring/wait-pressure-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/monitoring/blocking-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/monitoring/tempdb-pressure-snapshot` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/monitoring/io-stall-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/monitoring/memory-grant-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/security/failed-login-analysis` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `mssql/health/page-life-and-memory-pressure` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |

### Notes on Azure SQL DB partial coverage

- **`db-file-growth`** — `sys.master_files` is restricted on Azure SQL DB; the script falls back to `sys.database_files` when `SERVERPROPERTY('EngineEdition') = 5`. Server-level totals are not available on a single database.
- **`instance-overview`** — Some `SERVERPROPERTY` values (`MachineName`, `ProcessID`) and OS-level DMVs (`sys.dm_os_sys_info`) are unavailable. The script omits these rows on Azure SQL DB.

---

## PostgreSQL

| Script | 13 | 14 | 15 | 16 | 17 | Aurora PG | Cloud SQL PG |
| --- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `postgresql/performance/top-queries` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/performance/wait-events-summary` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/blocking/blocking-chain` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/storage/table-bloat-estimate` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/replication/replication-status` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/health/instance-overview` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/performance/unused-indexes` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/security/role-audit` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/health/connection-pressure` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/monitoring/health-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/monitoring/query-throughput-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/monitoring/vacuum-pressure-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `postgresql/monitoring/replication-lag-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/monitoring/io-and-buffer-snapshot` | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ | ⚠️ | ⚠️ |
| `postgresql/health/checkpoint-bgwriter-efficiency` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Notes
- **`top-queries`** requires the `pg_stat_statements` extension. RDS, Aurora and Cloud SQL all enable it via parameter groups.
- **`replication-status`** exposes `pg_replication_slots`. On managed services, replica details may be partial because the cloud control plane manages slots.
- **`instance-overview`** uses settings like `data_directory` that managed services hide. The script renders `<not exposed in this edition>` rather than failing.

---

## MySQL

| Script | 5.7 | 8.0 | 8.4 | Aurora MySQL | Percona Server |
| --- | :---: | :---: | :---: | :---: | :---: |
| `mysql/performance/top-queries` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/performance/innodb-row-lock-waits` | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| `mysql/blocking/blocking-chain` | ❌ | ✅ | ✅ | ✅ | ✅ |
| `mysql/storage/largest-tables` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/replication/replication-status` | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| `mysql/health/instance-overview` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/performance/unused-indexes` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/performance/io-and-buffer-pool` | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| `mysql/security/user-audit` | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| `mysql/monitoring/health-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/monitoring/query-throughput-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/monitoring/innodb-pressure-snapshot` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mysql/monitoring/replication-lag-snapshot` | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| `mysql/health/innodb-deep-status` | ⚠️ | ✅ | ✅ | ✅ | ✅ |

### Notes
- **`blocking-chain`** uses `performance_schema.data_locks` and `data_lock_waits`, available from MySQL 8.0. For 5.7, the `INFORMATION_SCHEMA.INNODB_LOCK_WAITS` equivalent is on the v2.1 backlog.
- **`innodb-row-lock-waits`** — the per-table section relies on `data_locks` (8.0+); on 5.7 only the cumulative section returns rows.
- **`replication-status`** uses the modern `performance_schema.replication_*` views (8.0+). On 5.7 the equivalents are partial — see vendor docs.

---

## MongoDB

| Script | 5.0 | 6.0 | 7.0 | 8.0 | Atlas |
| --- | :---: | :---: | :---: | :---: | :---: |
| `mongodb/performance/current-slow-ops` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mongodb/performance/profiler-summary` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/performance/index-usage` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mongodb/replication/replica-set-status` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/storage/collection-sizes` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/health/instance-overview` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/sharding/balancer-status` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/sharding/chunk-distribution` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/security/user-audit` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/monitoring/health-snapshot` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/monitoring/query-throughput-snapshot` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/monitoring/wt-cache-pressure-snapshot` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/monitoring/replication-lag-snapshot` | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| `mongodb/security/role-graph` | ✅ | ✅ | ✅ | ✅ | ⚠️ |

### Notes on Atlas partial coverage
- Free / Shared (M0–M5) tiers expose a subset of `serverStatus`, `hostInfo`, and `db.runCommand({ collStats })`. The scripts tolerate missing fields (rendering `<n/a>`) rather than throwing.
- On dedicated tiers (M10+), full output is available.
- `replica-set-status` reads `local.oplog.rs` directly. Atlas restricts direct access to `local`; the oplog window line shows `<n/a>` on Atlas.

---

## Adding a row

When you add a new script, add a row to the appropriate engine table. The `Engine` field in the script header must agree with this matrix. The header validator will eventually enforce this — for now, it is a reviewer's check.
