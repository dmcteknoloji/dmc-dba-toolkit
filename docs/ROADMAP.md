# Roadmap

A toolkit that doesn't ship is a toolkit that doesn't matter. Versions below are intentionally small so each one ships.

---

## v1.0 — SQL Server starter pack ✅

Released 2026-04-30.

- 5 read-only diagnostic scripts (CPU, waits, blocking, file growth, instance overview).
- Standard header convention.
- Compatibility matrix, impact rating, output schema docs.
- CI: header validator + sqlfluff lint.

---

## v1.1 — SQL Server depth

Target: +6 weeks.

- `mssql/performance/missing-indexes.sql`
- `mssql/performance/plan-cache-bloat.sql`
- `mssql/performance/parameter-sniffing-suspects.sql`
- `mssql/blocking/deadlock-last-24h.sql` (parses `system_health` extended events)
- `mssql/storage/log-vlf-count.sql`
- `mssql/storage/largest-tables.sql`
- `mssql/storage/tempdb-pressure.sql`
- `mssql/security/sysadmin-audit.sql`
- `mssql/security/tde-status.sql`
- `mssql/security/orphaned-users.sql`
- `mssql/health/error-log-last-24h.sql`
- `mssql/health/backup-chain-health.sql`
- `mssql/ha/ag-status.sql`
- `mssql/ha/replication-lag.sql`
- `mssql/ha/quorum-and-listener.sql`

---

## v1.2 — PostgreSQL starter pack

Target: +12 weeks. Same 5-script structure, mirrored conventions.

- `postgresql/performance/top-cpu-queries.sql` (`pg_stat_statements`)
- `postgresql/performance/wait-events-summary.sql`
- `postgresql/blocking/blocking-chain.sql` (`pg_locks` + `pg_stat_activity` recursive CTE)
- `postgresql/storage/bloat-and-vacuum.sql`
- `postgresql/health/instance-overview.sql`

---

## v1.3 — MySQL starter pack

Target: +16 weeks.

- `mysql/performance/top-cpu-queries.sql` (`performance_schema.events_statements_summary_by_digest`)
- `mysql/performance/innodb-row-lock-waits.sql`
- `mysql/blocking/blocking-chain.sql` (`performance_schema.data_lock_waits`)
- `mysql/storage/largest-tables.sql`
- `mysql/health/instance-overview.sql`

---

## v1.4 — MongoDB starter pack

Target: +20 weeks. Distributed as `.js` files (mongosh) following the same header convention.

- `mongodb/performance/current-op.js`
- `mongodb/performance/profiler-slow-ops.js`
- `mongodb/blocking/long-running-ops.js`
- `mongodb/storage/coll-stats.js`
- `mongodb/health/replica-set-status.js`

---

## v2.0 — Cross-engine unification

Target: +1 year.

- Every starter script across all four engines emits a **unified output shape** (same column names, same types, same units).
- Optional JSON output mode for piping into monitoring/automation.
- Reference exporter (Python) that produces Parquet from any script's output.
- Compatibility matrix becomes a generated artefact, not hand-maintained.

---

## What this roadmap is not

- It is not a deadline contract. Versions ship when they meet the bar.
- It is not exhaustive. PRs that fit the standards can land outside the planned packs.
- It is not closed. If you have a strong proposal for a new direction, open a discussion before opening a PR.
