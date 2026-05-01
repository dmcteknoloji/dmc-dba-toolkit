# Authors

This toolkit is the work of practitioners — people who have actually been on the wrong end of a 3 AM page and lived to write a script about it.

## Creator and lead maintainer

**[Çağlar Özenç](https://linkedin.com/in/caglarozenc)** — _Microsoft MVP — Data Platform, founder of [DMC Bilgi Teknolojileri](https://linkedin.com/company/dmcteknoloji)_

A long-tenure SQL Server practitioner from Turkey — years of production engagements across SQL Server, PostgreSQL, MySQL and MongoDB; the kind of consultant whose CV is measured in incidents survived rather than slides delivered. Founder of DMC Bilgi Teknolojileri, lead architect of [Sentinel DB 360](https://sentineldb360.com), regular voice in the Turkish SQL Server community via [SQL Ekibi](https://sqlekibi.com).

Started this toolkit in April 2025 after one too many incident calls where the answer was buried in a different consultant's USB stick. The goal: build the diagnostic kit a senior DBA would actually trust, with documented schemas, a real CI pipeline, and the discipline to refuse anything that isn't safe to run on a production instance. The "no AI fluff, voice from the field" tone of every script in this repo is his — distilled from real 3-AM pages, real audit committees, real Nebim/SAP/Logo customers across two decades of sahadan duruş.

- **Personal site:** [caglarozenc.com](https://caglarozenc.com)
- **LinkedIn:** [linkedin.com/in/caglarozenc](https://linkedin.com/in/caglarozenc)
- **GitHub org:** [github.com/dmcteknoloji](https://github.com/dmcteknoloji)
- **Engagements:** enterprise SQL Server, PostgreSQL, MySQL and MongoDB consulting through DMC Bilgi Teknolojileri.
- **Platform:** lead architect of [Sentinel DB 360](https://sentineldb360.com) — DMC's multi-engine database observability platform.
- **Community:** [SQL Ekibi](https://sqlekibi.com) — Turkish-language SQL Server community and content hub.
- **Microsoft MVP** — Data Platform.

### DMC Bilgi Teknolojileri (Database Management Company)

- **Site:** [dmcteknoloji.com](https://dmcteknoloji.com)
- **LinkedIn:** [linkedin.com/company/dmcteknoloji](https://linkedin.com/company/dmcteknoloji)
- **GitHub:** [github.com/dmcteknoloji](https://github.com/dmcteknoloji)

### Our public platforms · Bizim açık platformlarımız

| Platform | URL | Purpose |
|---|---|---|
| **DMC Bilgi Teknolojileri** | [dmcteknoloji.com](https://dmcteknoloji.com) | Corporate site — services, contact, pricing inquiries. |
| **Sentinel DB 360** | [sentineldb360.com](https://sentineldb360.com) | The continuous, multi-instance, alert-driven version of this toolkit. |
| **SQL Ekibi** | [sqlekibi.com](https://sqlekibi.com) | Turkish-language SQL Server community. Articles, recipes, conferences. |
| **Çağlar Özenç** | [caglarozenc.com](https://caglarozenc.com) | Personal site — speaking engagements, MVP work, blog. |

## Contributors

When you contribute a script that ships, your name appears here. The bar isn't gatekept; the standards are. Read [`CONTRIBUTING.md`](./CONTRIBUTING.md) and open an issue.

<!-- contributors-list -->

_(no external contributors yet — open a PR and be the first)_

## Inspirations and intellectual debts

This toolkit stands on the shoulders of public work that DMC respects deeply. Where a specific technique came from a public source, the source is credited in the script's `Inspired by` header field. Recurring influences worth naming up front:

- **Paul Randal** (SQLskills) — wait statistics methodology and the public "benign waits" guidance.
- **Brent Ozar** and the First Responder Kit team — modern SQL Server diagnostics conventions.
- **Adam Machanic** — `sp_WhoIsActive`, the gold standard for active session diagnostics.
- **Glenn Berry** — the long-running SQL Server Diagnostic Information Queries series.
- **Ola Hallengren** — the maintenance solution that taught a generation of DBAs what "modular" means.
- **Greg Sabino Mullane** (Bucardo) — public PostgreSQL bloat estimation SQL.
- **Nikolay Samokhvalov** — `postgres_dba`'s structured approach to diagnostic reports.
- **Percona** — Percona Toolkit and the public MySQL/InnoDB monitoring playbook.
- **MongoDB Inc.** — the official manual and the database profiler reference.
- **Microsoft Learn** — public DMV documentation, our single source of truth for SQL Server.

We do not copy code. We learn the technique, write our own implementation, and credit the public source. That's how the DBA community has always worked.
