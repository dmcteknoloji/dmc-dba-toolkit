<div align="center">

# 🛡️ DMC DBA Toolkit

**Multi-engine. Schema-documented. CI-tested. Read-only by default.**

A modern, opinionated diagnostics kit for working DBAs.
Open one script — get a clear answer in 30 seconds.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![SQL Lint](https://img.shields.io/badge/lint-sqlfluff-1f6feb)](./.sqlfluff)
[![CI](https://img.shields.io/badge/ci-github%20actions-2088FF?logo=githubactions&logoColor=white)](./.github/workflows/lint.yml)
[![Engines](https://img.shields.io/badge/engines-SQL%20Server-CC2927?logo=microsoftsqlserver&logoColor=white)](./docs/COMPATIBILITY_MATRIX.md)
[![Roadmap](https://img.shields.io/badge/roadmap-PG%20%C2%B7%20MySQL%20%C2%B7%20Mongo-success)](./docs/ROADMAP.md)
[![Made by DMC](https://img.shields.io/badge/made%20by-DMC-0a0a0a)](https://github.com/dmc)

</div>

---

## 🧭 Why this exists

Every senior DBA has the same drawer of half-remembered DMV scripts: one from a blog in 2014, one from a conference USB stick, one written at 3 AM during an incident. They work — until they don't, on the engine version no one tested.

DMC DBA Toolkit is that drawer, **rebuilt with discipline**:

- **Every script has a standard header** — engine compatibility, performance impact, required permissions, full output schema. No surprises at 3 AM.
- **Read-only by default.** Anything that mutates state is flagged in red and lives in a separate folder. (None in v1.0.)
- **CI-tested.** Lint runs on every PR. Headers are validated by an actual parser.
- **Multi-engine roadmap.** Starts with SQL Server. PostgreSQL, MySQL, MongoDB next — same conventions, same header, same rating system.

Inspired by the giants — Brent Ozar's First Responder Kit, Adam Machanic's `sp_WhoIsActive`, Glenn Berry's diagnostic queries, Ola Hallengren's maintenance solution — and shaped by what's still missing.

---

## ⚡ 30-second start

```bash
git clone https://github.com/dmc/dmc-dba-toolkit.git
cd dmc-dba-toolkit
```

Open any `.sql` file in SSMS / Azure Data Studio / your favorite client. Read the header. Run the query.

That's it. No installer, no stored procedures dropped on `master`, no CLR. **Pure T-SQL, copy-paste safe.**

---

## 🎯 The 5 starters (v1.0)

| # | Script | Question it answers | Impact |
|---|---|---|---|
| 1 | [`top-cpu-queries`](./mssql/performance/top-cpu-queries.sql) | Which queries are eating my CPU right now? | 🟢 Light |
| 2 | [`wait-stats-summary`](./mssql/performance/wait-stats-summary.sql) | What is my server actually waiting on? | 🟢 Light |
| 3 | [`blocking-chain`](./mssql/blocking/blocking-chain.sql) | Who is blocking whom, and who is the lead? | 🟢 Light |
| 4 | [`db-file-growth`](./mssql/storage/db-file-growth.sql) | Where is my disk going? Which file is about to autogrow? | 🟢 Light |
| 5 | [`instance-overview`](./mssql/health/instance-overview.sql) | Give me the one-screen summary of this instance. | 🟢 Light |

> Every script is **read-only**. Every script is **safe on production**. Every script tells you, in its header, exactly what it does.

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
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
```

Every script in this repo carries this header. The format is enforced by [`scripts/validate_headers.py`](./scripts/validate_headers.py) on every PR.

→ Full convention: [`docs/HEADER_STANDARD.md`](./docs/HEADER_STANDARD.md)

---

## 📊 Compatibility matrix

| Script | 2016 | 2017 | 2019 | 2022 | Azure SQL DB | Azure SQL MI |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| top-cpu-queries | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| wait-stats-summary | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| blocking-chain | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| db-file-growth | ✅ | ✅ | ✅ | ✅ | ⚠️ partial | ✅ |
| instance-overview | ✅ | ✅ | ✅ | ✅ | ⚠️ partial | ✅ |

⚠️ partial = some columns unavailable on Azure SQL DB (single database). Each script's header marks unsupported sections.

→ Full matrix: [`docs/COMPATIBILITY_MATRIX.md`](./docs/COMPATIBILITY_MATRIX.md)

---

## 🚦 Impact rating

| Badge | Meaning |
|---|---|
| 🟢 **Light** | Pure DMV scan, milliseconds, safe to run on any production instance, any time. |
| 🟡 **Medium** | A few seconds, scans a moderate amount of metadata, fine on production but not in tight loops. |
| 🔴 **Heavy** | Touches plan cache, reads files, or runs DBCC-class operations. Run off-hours; read the script first. |

→ Full guide: [`docs/IMPACT_RATING.md`](./docs/IMPACT_RATING.md)

---

## 🗺️ Roadmap

- **v1.0** — SQL Server, 5 starter scripts, full standard ✅ *(you are here)*
- **v1.1** — SQL Server, +15 scripts (security, HA, deeper storage, deadlock graphs)
- **v1.2** — PostgreSQL, 5 starters (`pg_stat_statements`, blocking, bloat, replication slots, instance overview)
- **v1.3** — MySQL, 5 starters (`performance_schema`, slow log, InnoDB status, replication, instance overview)
- **v1.4** — MongoDB, 5 starters (`currentOp`, profiler, replica set, sharding, dbStats)
- **v2.0** — Cross-engine outputs adopt a unified JSON shape, ready for monitoring pipelines

→ Detail: [`docs/ROADMAP.md`](./docs/ROADMAP.md)

---

## 🤝 Contributing

PRs welcome. The bar is high but the path is clear:

1. Pick (or open) an issue with the `new-script` label.
2. Copy the header from any existing script.
3. `python scripts/validate_headers.py` must pass locally.
4. Document the output schema in `docs/OUTPUT_SCHEMAS.md`.
5. Add a row to the compatibility matrix.

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

Built by **DMC — Database Management Company**.
Stop pasting from blog posts. Run something a senior DBA already vetted.

</div>
