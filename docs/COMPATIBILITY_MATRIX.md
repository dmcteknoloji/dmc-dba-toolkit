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

### Notes on Atlas partial coverage
- Free / Shared (M0–M5) tiers expose a subset of `serverStatus`, `hostInfo`, and `db.runCommand({ collStats })`. The scripts tolerate missing fields (rendering `<n/a>`) rather than throwing.
- On dedicated tiers (M10+), full output is available.
- `replica-set-status` reads `local.oplog.rs` directly. Atlas restricts direct access to `local`; the oplog window line shows `<n/a>` on Atlas.

---

## Adding a row

When you add a new script, add a row to the appropriate engine table. The `Engine` field in the script header must agree with this matrix. The header validator will eventually enforce this — for now, it is a reviewer's check.
