# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- v1.1 — additional SQL Server scripts: security audit pack, HA/AG status, deeper storage, deadlock graph parser
- v1.2 — PostgreSQL starter pack (5 scripts)
- v1.3 — MySQL starter pack (5 scripts)
- v1.4 — MongoDB starter pack (5 scripts)

## [1.0.0] — 2026-04-30

### Added
- Initial public release.
- SQL Server starter pack — 5 read-only diagnostic scripts:
  - `mssql/performance/top-cpu-queries.sql`
  - `mssql/performance/wait-stats-summary.sql`
  - `mssql/blocking/blocking-chain.sql`
  - `mssql/storage/db-file-growth.sql`
  - `mssql/health/instance-overview.sql`
- Standard "Architect Header" convention enforced on every `.sql` file.
- Compatibility matrix (`docs/COMPATIBILITY_MATRIX.md`) covering SQL Server 2016 through 2022, Azure SQL DB, Azure SQL MI.
- Impact rating system (`docs/IMPACT_RATING.md`) — 🟢 Light · 🟡 Medium · 🔴 Heavy.
- Output schema dictionary (`docs/OUTPUT_SCHEMAS.md`) — every column documented.
- CI: `sqlfluff` lint + custom `scripts/validate_headers.py` header validator.
- Project hygiene: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `SECURITY.md`, issue & PR templates.

[Unreleased]: https://github.com/dmc/dmc-dba-toolkit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/dmc/dmc-dba-toolkit/releases/tag/v1.0.0
