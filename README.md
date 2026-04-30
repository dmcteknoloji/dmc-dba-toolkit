<div align="center">

# 🛡️ DMC DBA Toolkit

**Multi-engine. Schema-documented. CI-tested. Read-only by default.**

A modern, opinionated diagnostics kit for working DBAs.
Open one script — get a clear answer in 30 seconds.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![SQL Lint](https://img.shields.io/badge/lint-sqlfluff-1f6feb)](./.sqlfluff)
[![CI](https://img.shields.io/badge/ci-github%20actions-2088FF?logo=githubactions&logoColor=white)](./.github/workflows/lint.yml)
[![Engines](https://img.shields.io/badge/engines-MSSQL%20%C2%B7%20PostgreSQL%20%C2%B7%20MySQL%20%C2%B7%20MongoDB-success)](./docs/COMPATIBILITY_MATRIX.md)
[![Public docs only](https://img.shields.io/badge/sources-public%20vendor%20docs%20only-7c3aed)](./docs/HEADER_STANDARD.md#sources-policy-the-line-we-dont-cross)
[![Made by DMC](https://img.shields.io/badge/made%20by-DMC%20Bilgi%20Teknolojileri-0a0a0a)](https://github.com/dmcteknoloji)

_Created and maintained by **[Çağlar Özenç](./AUTHORS.md)** — Microsoft MVP, DMC Bilgi Teknolojileri._
_Started April 2025. **43 production-grade scripts** across four engines, all built on public vendor documentation._

🇹🇷 _Bilingual: most explanatory blocks include both English and Türkçe._

</div>

---

## 🧭 Why this exists

Every senior DBA has the same drawer of half-remembered diagnostic queries: one from a blog in 2014, one from a conference USB stick, one written at 3 AM during an incident. They work — until they don't, on the engine version no one tested.

DMC DBA Toolkit is that drawer, **rebuilt with discipline**:

- **Every script has a standard header** — engine compatibility, performance impact, required permissions, full output schema, attribution. No surprises at 3 AM.
- **Read-only by default.** Anything that mutates state is flagged in red and lives in a separate folder. (None in v2.0.)
- **CI-tested.** Lint runs on every PR. Headers are validated by an actual parser.
- **Multi-engine, day one.** SQL Server, PostgreSQL, MySQL and MongoDB — same conventions, same header, same impact rating system.
- **Built only on public vendor documentation.** No NDA, no private previews, no scraped internal docs. See the [sources policy](./docs/HEADER_STANDARD.md#sources-policy-the-line-we-dont-cross).

Inspired by the giants — Brent Ozar's First Responder Kit, Adam Machanic's `sp_WhoIsActive`, Glenn Berry's diagnostic queries, Ola Hallengren's maintenance solution, Nikolay Samokhvalov's `postgres_dba`, Percona Toolkit, the official MongoDB diagnostic playbooks — and shaped by what's still missing across all of them.

---

## ⚡ 30-second start

```bash
git clone https://github.com/dmcteknoloji/dmc-dba-toolkit.git
cd dmc-dba-toolkit
```

Open any `.sql` (or `.js` for MongoDB) file in your favourite client. Read the header. Run.

That's it. No installer, no stored procedures dropped on your instance, no CLR, no extensions. **Pure vendor-native, copy-paste safe.**

---

## 📚 Script catalog

### 🟦 SQL Server (`mssql/`)

| Script | Question it answers | Impact |
|---|---|---|
| [`top-cpu-queries`](./mssql/performance/top-cpu-queries.sql) | Which queries are eating my CPU right now? | 🟢 |
| [`wait-stats-summary`](./mssql/performance/wait-stats-summary.sql) | What is my server actually waiting on? | 🟢 |
| [`missing-indexes`](./mssql/performance/missing-indexes.sql) | Which indexes does the optimiser keep asking for? | 🟢 |
| [`blocking-chain`](./mssql/blocking/blocking-chain.sql) | Who is blocking whom, and who is the lead? | 🟢 |
| [`db-file-growth`](./mssql/storage/db-file-growth.sql) | Where is my disk going? Which file is about to autogrow? | 🟢 |
| [`instance-overview`](./mssql/health/instance-overview.sql) | One-screen summary of this instance. | 🟢 |
| [`sysadmin-audit`](./mssql/security/sysadmin-audit.sql) | Who effectively has full server control (incl. nested roles)? | 🟢 |
| [`tde-status`](./mssql/security/tde-status.sql) | Encryption state per database; cert expiry. | 🟢 |
| [`orphaned-users`](./mssql/security/orphaned-users.sql) | DB users with no matching server login (post-restore). | 🟢 |
| [`error-log-last-24h`](./mssql/health/error-log-last-24h.sql) | Severity 17+, login failures, IO/memory warnings. | 🟡 |
| [`backup-chain-health`](./mssql/health/backup-chain-health.sql) | Last full / diff / log backup per DB, gap flagged. | 🟢 |
| [`ag-status`](./mssql/ha/ag-status.sql) | Always On AG: replicas, sync state, redo/log queues. | 🟢 |
| [`health-snapshot`](./mssql/monitoring/health-snapshot.sql) | One-row periodic snapshot for cron + a target table. | 🟢 |

### 🟪 PostgreSQL (`postgresql/`)

| Script | Question it answers | Impact |
|---|---|---|
| [`top-queries`](./postgresql/performance/top-queries.sql) | Which queries dominate cumulative time? | 🟢 |
| [`wait-events-summary`](./postgresql/performance/wait-events-summary.sql) | What are sessions waiting on, right now? | 🟢 |
| [`unused-indexes`](./postgresql/performance/unused-indexes.sql) | Which indexes have zero scans since stats reset? | 🟢 |
| [`blocking-chain`](./postgresql/blocking/blocking-chain.sql) | Lock waits, granted vs requested, who blocks whom. | 🟢 |
| [`table-bloat-estimate`](./postgresql/storage/table-bloat-estimate.sql) | Which tables are bloated and need attention? | 🟡 |
| [`replication-status`](./postgresql/replication/replication-status.sql) | Replica lag, slot status, WAL position. | 🟢 |
| [`role-audit`](./postgresql/security/role-audit.sql) | Who is SUPERUSER, CREATEROLE, BYPASSRLS — incl. nested. | 🟢 |
| [`connection-pressure`](./postgresql/health/connection-pressure.sql) | Headroom, idle-in-transaction, breakdown by group. | 🟢 |
| [`instance-overview`](./postgresql/health/instance-overview.sql) | One-screen summary of this cluster. | 🟢 |
| [`health-snapshot`](./postgresql/monitoring/health-snapshot.sql) | One-row periodic snapshot for cron + a target table. | 🟢 |

### 🟧 MySQL (`mysql/`)

| Script | Question it answers | Impact |
|---|---|---|
| [`top-queries`](./mysql/performance/top-queries.sql) | Top consumers from `events_statements_summary_by_digest`. | 🟢 |
| [`innodb-row-lock-waits`](./mysql/performance/innodb-row-lock-waits.sql) | InnoDB row lock contention overview. | 🟢 |
| [`unused-indexes`](./mysql/performance/unused-indexes.sql) | Indexes never read since startup; size attributed. | 🟢 |
| [`io-and-buffer-pool`](./mysql/performance/io-and-buffer-pool.sql) | Hit rate, miss/sec, per-instance pool, top IO files. | 🟢 |
| [`blocking-chain`](./mysql/blocking/blocking-chain.sql) | Who is blocking whom, via `data_lock_waits`. | 🟢 |
| [`largest-tables`](./mysql/storage/largest-tables.sql) | Top tables by data + index size, fragmentation hint. | 🟢 |
| [`replication-status`](./mysql/replication/replication-status.sql) | Replica health, lag, threads. | 🟢 |
| [`user-audit`](./mysql/security/user-audit.sql) | SUPER, GRANT OPTION, dynamic privileges, host wildcards. | 🟢 |
| [`instance-overview`](./mysql/health/instance-overview.sql) | One-screen summary of this server. | 🟢 |
| [`health-snapshot`](./mysql/monitoring/health-snapshot.sql) | One-row periodic snapshot for cron + a target table. | 🟢 |

### 🟩 MongoDB (`mongodb/`, mongosh `.js`)

| Script | Question it answers | Impact |
|---|---|---|
| [`current-slow-ops`](./mongodb/performance/current-slow-ops.js) | What is taking too long *right now*? | 🟢 |
| [`profiler-summary`](./mongodb/performance/profiler-summary.js) | Aggregate slow ops from `system.profile`. | 🟢 |
| [`index-usage`](./mongodb/performance/index-usage.js) | Which indexes are pulling weight, which aren't. | 🟢 |
| [`replica-set-status`](./mongodb/replication/replica-set-status.js) | RS health, member states, oplog lag. | 🟢 |
| [`collection-sizes`](./mongodb/storage/collection-sizes.js) | Top collections by storage, index size, doc count. | 🟢 |
| [`balancer-status`](./mongodb/sharding/balancer-status.js) | Balancer state, recent migrations, per-shard chunks. | 🟢 |
| [`chunk-distribution`](./mongodb/sharding/chunk-distribution.js) | Chunk balance per collection, jumbo chunks, key shape. | 🟡 |
| [`user-audit`](./mongodb/security/user-audit.js) | Users with effective root; custom roles nesting danger. | 🟢 |
| [`instance-overview`](./mongodb/health/instance-overview.js) | One-screen summary of this deployment. | 🟢 |
| [`health-snapshot`](./mongodb/monitoring/health-snapshot.js) | One-document periodic snapshot for monitoring pipelines. | 🟢 |

> Every script is **read-only**. Every script is **safe on production**. Every script tells you, in its header, exactly what it does and where the technique came from.

---

## 🧱 Anatomy of a script

```sql
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : top-cpu-queries                                 ║
-- ║  Engine        : SQL Server 2016+ │ Azure SQL DB │ Azure SQL MI  ║
-- ║  Category      : performance                                     ║
-- ║  Impact        : 🟢 Light  (read-only, no plan recompile)         ║
-- ║  Permissions   : VIEW SERVER STATE                               ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#top-cpu-queries      ║
-- ║  Inspired by   : <public source, if applicable>                  ║
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
```

Required: `Script`, `Engine`, `Category`, `Impact`, `Permissions`, `Output schema`, `Version`, `License`.
Optional: `Inspired by`, `Tested on`. Validated by [`scripts/validate_headers.py`](./scripts/validate_headers.py) on every PR.

→ Full convention: [`docs/HEADER_STANDARD.md`](./docs/HEADER_STANDARD.md)

---

## 🔍 Sources policy

This toolkit ships only what we can publish without ambiguity:

- **Public vendor documentation only.** Every system view, DMV, catalog table, profiler command and counter is in the vendor's official, publicly accessible docs.
- **No NDA, no private previews, no scraped internal docs.**
- **Inspiration is welcome, copying is not.** When a public source clearly shaped a script (Paul Randal's wait-stats methodology, Greg Sabino Mullane's bloat estimation, Mark Callaghan's MySQL counters), the source is credited in the header **and** at the relevant section in the script.
- **License compatibility.** We do not import code from GPL/AGPL/proprietary projects. We learn the technique, then write our own.

→ Detailed policy: [`CONTRIBUTING.md#attribution-and-sources-policy`](./CONTRIBUTING.md#attribution-and-sources-policy)

---

## 📊 Compatibility matrix (summary)

| Engine | Coverage |
|---|---|
| **SQL Server** | 2016, 2017, 2019, 2022 · Azure SQL DB · Azure SQL MI |
| **PostgreSQL** | 13, 14, 15, 16, 17 · Aurora PG · Cloud SQL PG |
| **MySQL** | 5.7, 8.0, 8.4 · Aurora MySQL · Percona Server |
| **MongoDB** | 5.0, 6.0, 7.0, 8.0 · Atlas |

→ Full matrix per script: [`docs/COMPATIBILITY_MATRIX.md`](./docs/COMPATIBILITY_MATRIX.md)

---

## 🚦 Impact rating

| Badge | Meaning |
|---|---|
| 🟢 **Light** | Pure metadata scan, milliseconds, safe on any production instance. |
| 🟡 **Medium** | A few seconds, scans moderate amounts of metadata. Fine on production, not in tight loops. |
| 🔴 **Heavy** | Touches plan cache / files / DBCC-class operations. Run off-hours; read first. |

→ Full guide: [`docs/IMPACT_RATING.md`](./docs/IMPACT_RATING.md)

---

## 🗺️ Roadmap

- **v2.0** — All four engines, 6 scripts each, full standard ✅ *(you are here)*
- **v2.1** — Per-engine depth pack: security, HA, deeper storage, deadlock graphs (`+12 weeks` target)
- **v2.2** — Cross-engine unified output mode (optional JSON), reference Parquet exporter
- **v3.0** — Curated runbooks per symptom (CPU pegged, blocking storm, replication broken)

→ Detail: [`docs/ROADMAP.md`](./docs/ROADMAP.md)

---

## 🌟 When ad-hoc isn't enough → Sentinel DB 360

This toolkit is, by design, a **drawer of vetted snapshots**. You open the right script, you run it, you get an answer. That's the right tool for an incident, an audit, a 3 AM page, or a sanity check before a release.

It is _not_ what you want for **continuous, multi-instance, alert-driven** monitoring. For that, every team eventually wants four things the toolkit cannot give them:

- **Persistence** — every snapshot saved, queryable for trend, compare across weeks.
- **Multi-instance correlation** — "show me the top 10 most blocked instances across our entire fleet".
- **Alerting with context** — not just "CPU is high", but "CPU is high *and* this query started running 5 minutes before, *and* a long blocker is open on db X".
- **Senior-DBA-grade analysis** — "this looks like a parameter sniffing regression on plan X" — with the recommended fix, not just a graph.

That's exactly what **[Sentinel DB 360](https://github.com/dmcteknoloji)** does. Same engines, same depth, but multi-instance, continuous, and AI-assisted.

> _The toolkit is the screwdriver. Sentinel DB 360 is the workshop._

The free toolkit's `monitoring/health-snapshot` scripts are the **literal first row** of what Sentinel DB 360 collects — but Sentinel runs them every minute across every instance, persists the history in MongoDB, correlates with blocking/HA/security events, and surfaces actionable findings via a real-time dashboard.

If your team relies on a DBA to tab through a dozen scripts during incidents, that DBA is the bottleneck. Sentinel DB 360 turns the toolkit into a 24/7 standing capability.

→ DMC: <https://github.com/dmcteknoloji>
→ Demo, pricing, and trial inquiries: open an issue or reach out to the address listed on the org page.

---

## 🤝 Contributing

PRs welcome. The bar is high but the path is clear:

1. Pick (or open) an issue with the `new-script` label.
2. Copy the header from any existing script.
3. `python scripts/validate_headers.py` must pass locally.
4. Document the output schema in `docs/OUTPUT_SCHEMAS.md`.
5. Add a row to the compatibility matrix.
6. Read the [attribution policy](./CONTRIBUTING.md#attribution-and-sources-policy) — credit your sources.

→ [`CONTRIBUTING.md`](./CONTRIBUTING.md) · [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md)

---

## 🔒 Security & responsible use

Found a script that mutates state, leaks data, or misbehaves on a specific edition?
→ [`SECURITY.md`](./SECURITY.md)

---

## 📜 License

[MIT](./LICENSE) — use it, ship it, fork it. Attribution appreciated, not required.

---

<div align="center">

Built by **DMC Bilgi Teknolojileri** — _Database Management Company_.
Stop pasting from blog posts. Run something a senior DBA already vetted.

[`AUTHORS.md`](./AUTHORS.md) · [`CONTRIBUTING.md`](./CONTRIBUTING.md) · [`docs/`](./docs)

</div>
