# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- v2.1 — per-engine depth pack (security audit, HA/AG status for SQL Server, MySQL deadlock graph, Mongo sharding utilities).
- v2.2 — optional unified JSON output mode + Parquet exporter.
- v3.0 — runbooks per symptom, linked to the relevant scripts.

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

[Unreleased]: https://github.com/dmc/dmc-dba-toolkit/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v2.0.0
[1.5.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v1.5.0
[1.3.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v1.3.0
[1.0.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v1.0.0
[0.5.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v0.5.0
[0.3.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v0.3.0
[0.1.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v0.1.0
