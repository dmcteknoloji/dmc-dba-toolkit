# Authors

This toolkit is the work of practitioners — people who have actually been on the wrong end of a 3 AM page and lived to write a script about it.

## Creator and lead maintainer

**[Çağlar Özenç](https://linkedin.com/in/caglarozenc)** — _Microsoft MVP — Azure SQL & SQL Server (5 consecutive years), founder & CTO of [DMC Bilgi Teknolojileri](https://dmcteknoloji.com)_

Çağlar entered the industry in 2007 as a software developer and crossed over into data platform work in 2012, when SQL Server became his primary discipline. The early years included leading Pervasive SQL → SQL Server 2000 migration projects — the kind of unglamorous, high-stakes work that teaches the operational instincts this toolkit reflects. He grew that practice into a Cloud & Data Architecture consultancy as PostgreSQL, MySQL and MongoDB joined the standard stack of Turkish enterprises.

Today he runs that practice as the founder and CTO of DMC Bilgi Teknolojileri. Microsoft has recognised his contributions with the **MVP — Azure SQL & SQL Server** award **five consecutive years** running, on the basis of hundreds of Turkish-language technical articles, corporate and individual trainings, and conference talks at home and abroad. Lead architect of [Sentinel DB 360](https://sentineldb360.com), the platform that runs continuously what this toolkit captures one script at a time. Long-time contributor to the Turkish SQL Server community through [SQL Ekibi](https://sqlekibi.com).

Started this toolkit in April 2025 after one too many incident calls where the answer was buried in a different consultant's USB stick. The goal: a diagnostic kit a senior DBA would actually trust — documented schemas, a real CI pipeline, and the discipline to refuse anything that isn't safe to run on a production instance.

Based in Istanbul · contact: [caglar@dmcteknoloji.com](mailto:caglar@dmcteknoloji.com)

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
