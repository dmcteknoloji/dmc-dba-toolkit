# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- v2.6 — JSON output mode for monitoring scripts, Grafana dashboard JSON exports.
- v3.0 — runbooks per symptom, linked to the relevant scripts.

---

## [2.5.0] — 2026-05-01

The expert depth + honor roll release. **+8 scripts (64 → 72)** —
two security expert scripts, three monitoring expert scripts, three
health expert scripts — plus a new `docs/HONORS.md` crediting the
people whose public work shaped this toolkit.

### Added — Expert tier (8 new scripts)

**Security**
- `mssql/security/failed-login-analysis.sql` — XE system_health
  ring-buffer shredded for last-24h failed logins, with three triage
  patterns (credential stuffing, distributed brute force, multi-state
  probing) labelled per (login, host).
- `mongodb/security/role-graph.js` — full role-inheritance graph
  with cycle protection, transitive role expansion for users and
  roles, dangerous-built-in detection.

**Monitoring**
- `mssql/monitoring/io-stall-snapshot.sql` — per-file IO stall +
  average ms-per-IO latency from `sys.dm_io_virtual_file_stats`.
- `mssql/monitoring/memory-grant-snapshot.sql` — outstanding memory
  grants + workspace pressure + parameter-sniffing-suspect detection.
- `postgresql/monitoring/io-and-buffer-snapshot.sql` — `pg_stat_io`
  (PG 16+) with `pg_stat_bgwriter` fallback on PG 13-15.

**Health**
- `mssql/health/page-life-and-memory-pressure.sql` — per-NUMA-node
  Page Life Expectancy + top memory clerks + workspace headline.
- `postgresql/health/checkpoint-bgwriter-efficiency.sql` — three-way
  dirty-page write accounting (checkpoint vs bgwriter vs backend) +
  concrete tuning verdicts.
- `mysql/health/innodb-deep-status.sql` — structured equivalent of
  `SHOW ENGINE INNODB STATUS`: semaphores, buffer pool internals,
  redo log, MVCC history list, adaptive hash index.

### Added — `docs/HONORS.md`

A bilingual EN/TR honor roll. SQL Server giants (Paul Randal,
Brent Ozar, Adam Machanic, Glenn Berry, Ola Hallengren, Erik Darling,
Kendra Little, Itzik Ben-Gan, Jonathan Kehayias, Aaron Bertrand),
PostgreSQL voices (Greg Sabino Mullane, Nikolay Samokhvalov,
Bruce Momjian, Heikki Linnakangas, Robert Haas, Lukas Fittl,
Michael Christofides), MySQL/InnoDB authorities (Mark Callaghan,
Jeremy Cole, Peter Zaitsev, Baron Schwartz, Frédéric Descamps),
MongoDB voices, and cross-cutting contributors (Andy Pavlo,
Martin Kleppmann, Markus Winand). Plus the Turkish DBA community.

The page is explicitly a "living thank-you ledger" — open to
additions via PR.

### Changed

- README catalog gains 13 new rows across the four engines.
- README navigation adds a **Honors** entry between Monitoring and
  Vs-Other-Toolkits.
- Tagline updated: "72 production-grade scripts across four engines".
- LEARNING_PATHS expert section header updated to "16+ and growing"
  (now lists 20 expert-tier scripts).

**72/72 scripts pass header validation.**

---

## [2.4.0] — 2026-05-01

The bilingual completion + ecosystem release. Every script now carries
a Turkish summary alongside its English content, and the four DMC
platform domains are linked from every README.

### Changed — Bilingual completion (TR mirror retroactive)

- All 34 v1.0 / v2.0 scripts that previously had English-only prose
  now carry a `🇹🇷 Türkçe özet` block immediately after the box-art
  header. Each summary is 4-5 lines, specific to the script's actual
  behaviour and caveats. Existing English content is preserved.
- **64/64 scripts have TR content** — closes the gap between newer
  scripts (v2.1+, bilingual by convention) and the original v1.0/v2.0.

### Added — DMC platform ecosystem references

Linked from every README, `AUTHORS.md`, and the issue-template menu:

- [`dmcteknoloji.com`](https://dmcteknoloji.com) — DMC corporate site.
- [`sentineldb360.com`](https://sentineldb360.com) — Sentinel DB 360,
  the continuous-monitoring platform.
- [`sqlekibi.com`](https://sqlekibi.com) — SQL Ekibi, Turkish-language
  SQL Server community.
- [`caglarozenc.com`](https://caglarozenc.com) — personal site of the
  toolkit's maintainer.

### Changed — Sentinel DB 360 link target

Every Markdown link of the form
`[Sentinel DB 360](https://github.com/dmcteknoloji)` now points at
`https://sentineldb360.com` — the actual product page. The DMC
organisation link (`github.com/dmcteknoloji`) is unchanged and
correctly points at the source repository home.

**64/64 scripts pass header validation.**

---

## [2.3.0] — 2026-05-01

The skill-level release. **+8 scripts (56 → 64)** plus a `Level` field
applied retroactively to every existing script, a new `LEARNING_PATHS.md`
curriculum doc, and bumped expert depth across all four engines.

### Added — Conventions

- New header field: `Level` (🌱 Newborn / 🌳 Middle / 🦅 Expert).
  Applied to all 56 existing scripts and required on new ones going forward.
  Field-level definition lives in `docs/HEADER_STANDARD.md#skill-levels`.

### Added — Newborn tier (4 scripts)

Tutorial-style scripts with extensive bilingual commentary aimed at
DBAs in their first year:

- `mssql/health/getting-started.sql` — what is a DMV, where am I?
- `postgresql/health/getting-started.sql` — what are the `pg_stat_*` views?
- `mysql/health/getting-started.sql` — system variables vs status variables.
- `mongodb/health/getting-started.js` — admin commands tutorial.

### Added — Expert tier (4 scripts)

Senior-grade depth for practitioners who already know the area:

- `mssql/blocking/deadlock-graph-parser.sql` — XML shredding the
  system_health Extended Events ring buffer to extract every recent
  deadlock as a tabular row.
- `postgresql/blocking/lock-mode-conflict-matrix.sql` — joins
  `pg_locks` against itself with the official 8×8 conflict matrix
  to show *why* each block exists, including the held-mode ×
  requested-mode pair.
- `mysql/performance/innodb-trx-deep.sql` — `INNODB_TRX` × `data_locks`
  × `processlist` deep cross-join with verdict text per transaction.
- `mongodb/performance/oplog-tailing-pattern.js` — reads the last N
  seconds of `local.oplog.rs`, aggregates by namespace + op type,
  surfaces multi-document transactions and noisy collections.

### Added — Documentation

- `docs/LEARNING_PATHS.md` — bilingual curriculum: which 8 Newborn
  scripts to start with, which curated paths to follow as a Middle-tier
  DBA, which 12 Expert-tier scripts to chase last. Closes with the
  natural bridge to Sentinel DB 360.

### Changed

- README catalog gains a "Learning paths" entry as the first item in
  the navigation section.
- Tagline updated: "64 production-grade scripts across four engines —
  three skill levels".
- Header validator (`scripts/validate_headers.py`) tolerates the new
  `Level` field; existing scripts have been bulk-updated to include it.

**64/64 scripts pass header validation.**

---

## [2.2.0] — 2026-05-01

The Continuous Monitoring Snapshot Suite. **+13 monitoring scripts** (43 → 56 total) plus three new translated READMEs and a comprehensive setup guide.

### Added — Monitoring suite (one row per execution; cron-friendly)

**SQL Server +4**
- `mssql/monitoring/query-throughput-snapshot.sql` — batch req/sec, compilation/recompilation rates, compile-to-batch ratio.
- `mssql/monitoring/wait-pressure-snapshot.sql` — per-category wait time (CPU, IO, Lock, Latch, Buffer IO, Buffer Latch, Memory, Network, Compilation, Other), signal-wait %, ready for time-series.
- `mssql/monitoring/blocking-snapshot.sql` — blocked sessions, lead blocker context, longest wait, dominant wait type — turns blocking from "moments" into "patterns".
- `mssql/monitoring/tempdb-pressure-snapshot.sql` — user/internal/version-store sizes, allocation contention on PFS/GAM/SGAM pages.

**PostgreSQL +3**
- `postgresql/monitoring/query-throughput-snapshot.sql` — commits, rollbacks, blks_hit/read, BG writer cumulative.
- `postgresql/monitoring/vacuum-pressure-snapshot.sql` — worst dead-tuple ratio, oldest unfrozen xid age, oldest xmin holder transaction (the "vacuum cliff" predictor).
- `postgresql/monitoring/replication-lag-snapshot.sql` — worst standby lag in bytes/secs, slot WAL retention, inactive-slot detection.

**MySQL +3**
- `mysql/monitoring/query-throughput-snapshot.sql` — Questions, Com_*, Slow_queries, Aborted_clients, plus rate-since-startup averages.
- `mysql/monitoring/innodb-pressure-snapshot.sql` — buffer pool fill, dirty %, hit rate, row lock signals, IO pending — the four dimensions every MySQL DBA wants on a chart.
- `mysql/monitoring/replication-lag-snapshot.sql` — canonical lag-in-seconds, applier worker state, last error message.

**MongoDB +3**
- `mongodb/monitoring/query-throughput-snapshot.js` — opcounters cumulative, network bytes, active clients/readers/writers.
- `mongodb/monitoring/wt-cache-pressure-snapshot.js` — cache fill, dirty %, app-thread eviction (the leading indicator that hides until query latency degrades).
- `mongodb/monitoring/replication-lag-snapshot.js` — per-secondary lag in seconds, oplog window minutes, stuck-optime detection.

### Added — Multi-language READMEs

- `README.es.md` — Spanish.
- `README.de.md` — German.
- `README.ja.md` — Japanese.
- Language switcher at the top of the main README.

(Scripts remain bilingual EN + TR in their explanatory blocks; the multi-language READMEs cover the orientation surface.)

### Added — Documentation

- `docs/MONITORING_GUIDE.md` — comprehensive setup recipes for SQL Agent / pg_cron / MySQL Event Scheduler / mongosh cron, plus retention strategies and Grafana / Power BI hookup. Bilingual where it matters; ends with the natural bridge to Sentinel DB 360.

### Changed

- README catalog reorganised; new "Playbooks, monitoring & positioning" section linking `PLAYBOOKS.md`, `MONITORING_GUIDE.md`, `VS_OTHER_TOOLKITS.md`.
- Tagline updated: "56 production-grade scripts across four engines".

**56/56 scripts pass header validation.**

---

## [2.1.1] — 2026-05-01

The depth-pack release. **+19 scripts** (43 total). Adds security, HA, sharding and a minimal monitoring tier — plus a documented bridge to continuous monitoring via Sentinel DB 360.

### Added — Engines

- **SQL Server +6**: `sysadmin-audit`, `tde-status`, `orphaned-users`, `error-log-last-24h`, `backup-chain-health`, `ag-status`.
- **PostgreSQL +3**: `unused-indexes`, `role-audit`, `connection-pressure`.
- **MySQL +3**: `unused-indexes`, `user-audit`, `io-and-buffer-pool`.
- **MongoDB +3**: `balancer-status`, `chunk-distribution`, `user-audit`.

### Added — Monitoring tier

- New `monitoring/` category: one `health-snapshot` per engine — minimal one-row periodic snapshots designed for cron + a target table. Intentionally a teaser for what continuous monitoring looks like; production-grade is what Sentinel DB 360 is for.

### Added — Conventions

- **Bilingual format** (EN + TR) — the "Why this exists" and "Production note" blocks now ship in both languages on new scripts. Existing scripts will be retro-translated in patch releases.
- New categories accepted by `validate_headers.py`: `sharding`, `monitoring`.

### Changed

- README catalog reorganised; new "Sentinel DB 360" section explains where the toolkit ends and continuous monitoring begins.
- All scripts pass `scripts/validate_headers.py` (43/43).

---

## [2.0.0] — 2026-04-01

The "all four engines" release.

### Added — Engines
- **PostgreSQL pack** (6 scripts): `top-queries`, `wait-events-summary`, `blocking-chain`, `table-bloat-estimate`, `replication-status`, `instance-overview`. Targets PG 13–17 plus Aurora PG and Cloud SQL.
- **MySQL pack** (6 scripts): `top-queries`, `innodb-row-lock-waits`, `blocking-chain`, `largest-tables`, `replication-status`, `instance-overview`. Targets MySQL 5.7 / 8.0 / 8.4, Aurora MySQL, Percona Server.
- **MongoDB pack** (6 scripts, mongosh `.js`): `current-slow-ops`, `profiler-summary`, `replica-set-status`, `index-usage`, `collection-sizes`, `instance-overview`. Targets MongoDB 5.0+ and Atlas.

### Added — SQL Server depth
- `mssql/performance/missing-indexes.sql` — sixth SQL Server script, parity with the other engines.

### Added — Conventions
- Optional header fields: `Inspired by`, `Tested on`, `Maintainer`, `Last updated`.
- "Sources policy" — the line we don't cross — formalised in `docs/HEADER_STANDARD.md` and `CONTRIBUTING.md`.
- `AUTHORS.md` — creator, contributors, and inspirations credited explicitly.

### Changed
- Header validator now accepts `.js` files (mongosh) alongside `.sql`, with the same field-line grammar (`// ║ ... ║`).
- README catalog reorganised by engine; matrix and roadmap rewritten for v2.0 scope.
- LICENSE attribution updated to reflect Çağlar Özenç (DMC Bilgi Teknolojileri) as the copyright holder.

---

## [1.5.0] — 2026-02-25

PostgreSQL beta — first non-SQL-Server engine joins the family.

### Added
- Initial PostgreSQL beta pack: `top-queries`, `wait-events-summary`, `blocking-chain`, `instance-overview` (4 of the eventual 6).
- Header validator gains `replication` as a valid category in preparation for v2.0.

### Changed
- Compatibility matrix structure updated to support multiple engines.

---

## [1.3.0] — 2025-12-19

Preview pack and conventions hardening.

### Added
- MySQL preview: `blocking-chain.sql` ships first as a proof-of-concept ahead of the full MySQL pack in v2.0.
- `Inspired by` optional header field — first time we formally attribute Paul Randal's wait-stats methodology.

### Fixed
- Header validator regex now tolerates trailing whitespace inside the box drawing.

---

## [1.0.0] — 2025-09-28

The first stable release. SQL Server only, but every script vetted in the field.

### Added
- SQL Server starter pack (5 scripts): `top-cpu-queries`, `wait-stats-summary`, `blocking-chain`, `db-file-growth`, `instance-overview`.
- Standard "Architect Header" convention enforced on every `.sql` file.
- Compatibility matrix (`docs/COMPATIBILITY_MATRIX.md`) covering SQL Server 2016 through 2022, Azure SQL DB, Azure SQL MI.
- Impact rating system (`docs/IMPACT_RATING.md`) — 🟢 Light · 🟡 Medium · 🔴 Heavy.
- Output schema dictionary (`docs/OUTPUT_SCHEMAS.md`).
- CI: `sqlfluff` lint + custom `scripts/validate_headers.py`.
- Project hygiene: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `SECURITY.md`, issue & PR templates.

---

## [0.5.0] — 2025-08-12

### Added
- `mssql/storage/db-file-growth.sql` — Azure SQL DB-aware fallback for environments where `sys.master_files` is restricted.

### Changed
- Header standard formalised: 8 required fields, box-drawing format. Older drafts had a freeform header.

---

## [0.3.0] — 2025-06-30

### Added
- `mssql/blocking/blocking-chain.sql` — recursive CTE rooted at lead blockers.

### Changed
- Repository moved from a single-folder layout to engine-categorised folders (`mssql/<category>/`) in preparation for multi-engine ambitions.

---

## [0.1.0] — 2025-04-15

### Added
- First commit. `top-cpu-queries.sql` extracted from a consultancy notebook into a standalone, header-documented script. The toolkit is born.

---

[Unreleased]: https://github.com/dmcteknoloji/dmc-dba-toolkit/compare/v2.5.0...HEAD
[2.5.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.5.0
[2.4.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.4.0
[2.3.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.3.0
[2.2.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.2.0
[2.1.1]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.1.1
[2.1.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.1.0
[2.0.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v2.0.0
[1.5.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v1.5.0
[1.3.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v1.3.0
[1.0.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v1.0.0
[0.5.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v0.5.0
[0.3.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v0.3.0
[0.1.0]: https://github.com/dmcteknoloji/dmc-dba-toolkit/releases/tag/v0.1.0
