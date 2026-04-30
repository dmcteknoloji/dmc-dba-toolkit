# Roadmap

A toolkit that doesn't ship is a toolkit that doesn't matter. Versions below are intentionally small so each one ships.

---

## v2.0 — All four engines ✅

Released 2026-04-01. **You are here.**

- **24 read-only diagnostic scripts** — 6 per engine (SQL Server, PostgreSQL, MySQL, MongoDB).
- Standard header convention with optional `Inspired by`, `Maintainer`, `Last updated` fields.
- Compatibility matrix expanded to four engines and their managed-cloud variants.
- CI: header validator (with `.js` support) + `sqlfluff` lint + Markdown link check.
- Sources policy formalised — public vendor docs only, attribution mandatory.

---

## v2.1 — Per-engine depth pack

Target: +12 weeks.

**SQL Server**
- `mssql/security/sysadmin-audit.sql`
- `mssql/security/tde-status.sql`
- `mssql/health/error-log-last-24h.sql`
- `mssql/health/backup-chain-health.sql`
- `mssql/ha/ag-status.sql`
- `mssql/ha/replication-lag.sql`

**PostgreSQL**
- `postgresql/performance/index-usage-and-bloat.sql`
- `postgresql/security/role-audit.sql`
- `postgresql/health/connection-pressure.sql`

**MySQL**
- `mysql/performance/io-and-buffer-pool.sql`
- `mysql/storage/innodb-fragmentation.sql`
- `mysql/security/user-audit.sql`

**MongoDB**
- `mongodb/sharding/balancer-status.js`
- `mongodb/sharding/chunk-distribution.js`
- `mongodb/security/user-audit.js`

---

## v2.2 — Optional unified output mode

Target: +20 weeks.

- Each script gains a `--json` mode that emits a per-row JSON document with vendor-neutral keys.
- Reference Python exporter (`scripts/export_to_parquet.py`) that writes any script's output to Parquet for downstream analytics.
- Compatibility matrix becomes a generated artefact, not hand-maintained.

---

## v3.0 — Runbooks per symptom

Target: +1 year.

- Markdown runbooks shipped under `runbooks/`, each one symptom-first ("CPU pegged at 100%", "Replica falling behind", "Bloat eating the disk").
- Each runbook references the relevant toolkit scripts at each step, in order.
- A reader on a phone, at 2 AM, can follow a runbook end-to-end.

---

## What this roadmap is not

- It is not a deadline contract. Versions ship when they meet the bar.
- It is not exhaustive. PRs that fit the standards can land outside the planned packs.
- It is not closed. If you have a strong proposal for a new direction, open a discussion before opening a PR.
