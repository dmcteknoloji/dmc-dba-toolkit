# Compatibility Matrix

Authoritative compatibility data for every script in the toolkit. Updated on every release.

Legend:
- ✅ Tested and supported.
- ⚠️ Partial — some columns or sections behave differently. See script header.
- ❌ Not supported on this engine/edition.
- ❓ Untested. Community confirmation welcome.

---

## SQL Server

| Script | 2016 | 2017 | 2019 | 2022 | Azure SQL DB | Azure SQL MI |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| `mssql/performance/top-cpu-queries` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/performance/wait-stats-summary` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/blocking/blocking-chain` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `mssql/storage/db-file-growth` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| `mssql/health/instance-overview` | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |

### Notes on Azure SQL DB partial coverage

- **`db-file-growth`** — `sys.master_files` is restricted on Azure SQL DB; the script falls back to `sys.database_files` when `SERVERPROPERTY('EngineEdition') = 5`. Server-level totals are not available on a single database.
- **`instance-overview`** — Some `SERVERPROPERTY` values (`MachineName`, `ProcessID`) and OS-level DMVs (`sys.dm_os_sys_info`) are unavailable. The script omits these rows on Azure SQL DB.

---

## PostgreSQL

*Planned for v1.2. Current entries: none.*

---

## MySQL

*Planned for v1.3. Current entries: none.*

---

## MongoDB

*Planned for v1.4. Current entries: none.*

---

## Adding a row

When you add a new script, add a row here in the appropriate engine table. The `Engine` field in the script header must agree with this matrix; the header validator will eventually enforce this.
