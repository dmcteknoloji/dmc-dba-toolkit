# Roadmap

A toolkit that doesn't ship is a toolkit that doesn't matter. Versions below are intentionally small so each one ships.

---

## v2.0 — All four engines ✅

Released 2026-04-01.

- **24 read-only diagnostic scripts** — 6 per engine (SQL Server, PostgreSQL, MySQL, MongoDB).
- Standard header convention with optional `Inspired by`, `Maintainer`, `Last updated` fields.
- Compatibility matrix expanded to four engines and their managed-cloud variants.
- CI: header validator (with `.js` support) + `sqlfluff` lint + Markdown link check.
- Sources policy formalised — public vendor docs only, attribution mandatory.

---

## v2.1 — Depth pack + monitoring tier ✅

Released 2026-05-01. **You are here.** **+19 scripts, 43 total.**

- SQL Server +6: sysadmin-audit, tde-status, orphaned-users, error-log-last-24h, backup-chain-health, ag-status.
- PostgreSQL +3: unused-indexes, role-audit, connection-pressure.
- MySQL +3: unused-indexes, user-audit, io-and-buffer-pool.
- MongoDB +3: balancer-status, chunk-distribution, user-audit.
- Monitoring tier: one `health-snapshot` per engine (cron-friendly snapshot scripts).
- Bilingual format (EN + TR) on the explanatory blocks.
- Sentinel DB 360 bridge — README explains where the toolkit ends and continuous monitoring begins.

---

## v2.2 — Bilingual completion + JSON output

Target: +8 weeks.

- Retro-translate explanatory blocks of the v2.0 scripts to bilingual format.
- Optional `--json` mode on every script that emits structured rows, suitable for piping into TSDBs and dashboards.
- Reference Python exporter (`scripts/export_to_parquet.py`) that runs any script and writes to Parquet.

---

## v2.3 — Second-wave depth scripts

Target: +14 weeks.

- SQL Server: replication-lag (log shipping + AG), tempdb-pressure deep, plan-cache-bloat, parameter-sniffing-suspects.
- PostgreSQL: index-bloat-estimate, vacuum-progress, longest-running-vacuums, autovacuum-tuning-hints.
- MySQL: innodb-fragmentation, deadlock-graph (parses `SHOW ENGINE INNODB STATUS` deadlock section), max-conn-history.
- MongoDB: oplog-window-history, slow-op-distribution, balancer-history.

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
