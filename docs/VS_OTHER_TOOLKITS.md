# DMC DBA Toolkit vs the giants

> Honest positioning. The DBA community has been building diagnostic tools for two decades. This page explains who built what, what each one is best at, and where DMC fits.
>
> Dürüst konumlandırma. DBA topluluğu yirmi yıldır tanı araçları geliştiriyor. Bu sayfa kimin neyi yaptığını, her birinin ne için en iyi olduğunu ve DMC'nin nereye oturduğunu anlatır.

---

## TL;DR

| Toolkit | Engine | Format | Best for | Lisans |
|---|---|---|---|---|
| **[Brent Ozar's First Responder Kit](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)** | SQL Server | Stored procs | Long-form server health checks (`sp_Blitz`) | MIT |
| **[sp_WhoIsActive](https://github.com/amachanic/sp_whoisactive)** | SQL Server | One stored proc | "Who's running what right now" — every shop installs it | GPLv3 |
| **[Glenn Berry's Diagnostic Queries](https://glennsqlperformance.com/resources/)** | SQL Server | Versioned `.sql` files | Single-version deep DMV reference | Free, non-GitHub |
| **[Ola Hallengren](https://ola.hallengren.com/)** | SQL Server | Stored procs + scheduler | Maintenance: backups, integrity, indexes | MIT |
| **[postgres_dba](https://github.com/NikolayS/postgres_dba)** | PostgreSQL | Interactive psql menu | psql-native menu of 34 reports | BSD-3 |
| **[Percona Toolkit](https://github.com/percona/percona-toolkit)** | MySQL (mainly) | CLI Perl tools | `pt-query-digest`, online schema change | GPLv2 |
| **[mtools](https://github.com/rueckstiess/mtools)** | MongoDB | Python | Log parsing, mlaunch test clusters | Apache-2.0 |
| **DMC DBA Toolkit** | **All four** | `.sql` / `.js` | **Multi-engine, schema-documented, CI-tested, NDA-safe** | **MIT** |

---

## What each one does best

### Brent Ozar — First Responder Kit
**Strength.** `sp_Blitz` and `sp_BlitzFirst` are the canonical "give me a 1-page health report" stored procedures for SQL Server. The community is large, the test surface is real, the tone is opinionated in a way that helps beginners.

**Where it stops.** SQL Server only. No CI, no formal output schema documentation, no header convention. Recently added "AI" features in `sp_BlitzIndex` are interesting but optional.

### Adam Machanic — sp_WhoIsActive
**Strength.** Eighteen years of maintenance. One job, done exceptionally. Every senior SQL Server DBA has it pre-installed. Output columns are stable across versions; you build dashboards on top.

**Where it stops.** Single tool, single engine, single workflow. Not designed to grow into a toolkit; designed to remain the best at one thing. GPLv3 means commercial vendors can't ship modified versions inside their own products without sharing source.

### Glenn Berry — Diagnostic Information Queries
**Strength.** The reference for SQL Server DMV expertise. Updated monthly. Each query is annotated with "what this tells you, what to look for, why it matters".

**Where it stops.** Distributed via Dropbox, not GitHub. No CI, no automation surface. Targeted at DBAs reading the queries; not designed for downstream tooling.

### Ola Hallengren — SQL Server Maintenance Solution
**Strength.** The de-facto standard for SQL Server backup and maintenance scheduling. Modular, version-supported back to 2008 and forward through 2025+ Azure variants. Commercial vendors include it without modification.

**Where it stops.** Maintenance, not diagnostics. Different problem space than this toolkit; complementary, not overlapping.

### Nikolay Samokhvalov — postgres_dba
**Strength.** Interactive psql menu. 34 reports. PG13–18. Zero dependencies — pure SQL. Uses extensions (`pg_stat_statements`, `amcheck`, `pgstattuple`) when available, gracefully degrades when not.

**Where it stops.** PostgreSQL only. Workflow is interactive (a menu in psql) — not the right shape for batch use or when you want to run a single script ad hoc.

### Percona — Percona Toolkit
**Strength.** `pt-query-digest` is the community standard for MySQL slow log analysis. `pt-online-schema-change` makes massive schema changes possible without locking. Used in production at scale at most non-trivial MySQL shops.

**Where it stops.** Perl CLI tools, not SQL scripts. GPLv2 license. Largely MySQL-focused (some PostgreSQL coverage). Not the same shape as DMC — they are operational tools, this is a diagnostic library.

### MongoDB Inc. — official manual + community tools
**Strength.** `db.currentOp()`, the database profiler, `rs.status()`, `sh.status()` — the official toolset is comprehensive and well-documented. mtools is the most-used community add-on.

**Where it stops.** MongoDB-specific, fragmented across many separate commands. No unified diagnostic library.

---

## Where DMC sits

DMC DBA Toolkit is **not trying to replace any of the above.** They are the giants we stand on.

What DMC adds is the dimension nobody else covers in one place:

1. **Multi-engine.** SQL Server, PostgreSQL, MySQL, MongoDB — same conventions, same header, same compatibility matrix shape, same impact rating system.
2. **Schema-documented output.** Every column documented in `docs/OUTPUT_SCHEMAS.md`. Build dashboards or exports on top with confidence.
3. **CI-tested headers.** A Python validator runs on every PR. The header standard isn't a suggestion; it's enforced.
4. **NDA-safe sources policy.** Every script ships with `Inspired by` attribution; every system view used is in the vendor's public docs. We won't merge anything that requires private content.
5. **Bilingual (EN + TR) explanatory blocks.** A first-class feature for the Turkish DBA community that DMC operates in.
6. **A clear path to continuous monitoring.** Each `monitoring/health-snapshot` script is the literal first row of what [Sentinel DB 360](https://sentineldb360.com) collects. The free toolkit is a sincere on-ramp, not a tease.

---

## When to use what

If your shop is **SQL Server only** and you want one tool: install `sp_WhoIsActive`. Add Ola Hallengren's maintenance solution. Then use this toolkit for the diagnostic gaps neither covers.

Sadece SQL Server kullanıyorsanız: `sp_WhoIsActive` + Ola Hallengren maintenance + boşluklar için bu toolkit.

If your shop is **PostgreSQL only**: postgres_dba is excellent. This toolkit is complementary — fewer reports, but the same conventions you'll find on MySQL/Mongo when those land in your stack.

Sadece PostgreSQL: postgres_dba mükemmel. Bu toolkit tamamlayıcıdır — daha az rapor, ama MySQL/Mongo eklendiğinde aynı konvansiyonu bulacaksınız.

If your shop is **MySQL-heavy**: Percona Toolkit for operational, Percona Server's status tables, this toolkit for the diagnostic library shape.

If your shop is **multi-engine** (which most non-trivial shops eventually are): this is what DMC is designed for.

If your shop has **3+ instances and recurring incidents**: see [Sentinel DB 360](https://sentineldb360.com) — the toolkit is the screwdriver, the platform is the workshop.

---

## Reciprocal acknowledgement

Where any of the above shaped a specific technique in this toolkit, the script's `Inspired by` header field credits it. We are deliberate about this:

- Paul Randal (SQLskills) — wait-stats benign list — credited in `mssql/performance/wait-stats-summary.sql`.
- Greg Sabino Mullane (Bucardo) — bloat estimation SQL — credited in `postgresql/storage/table-bloat-estimate.sql`.
- The official Microsoft Learn / postgresql.org / dev.mysql.com / mongodb.com docs — the foundation of every script.

The DBA community has always been generous with knowledge. This toolkit aims to be a good citizen of that tradition.
