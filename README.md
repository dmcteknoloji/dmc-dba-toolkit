<div align="center">

<img src="./assets/logo.svg" alt="DMC — Database Management Company" width="380">

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
_Started April 2025. **56 production-grade scripts** across four engines, all built on public vendor documentation._

🌐 **English** · [Türkçe içerik scriptlerin içinde](./docs/PLAYBOOKS.md) · [Español](./README.es.md) · [Deutsch](./README.de.md) · [日本語](./README.ja.md)

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
| [`query-throughput-snapshot`](./mssql/monitoring/query-throughput-snapshot.sql) | Batch req/sec, compilation/recompilation rates. | 🟢 |
| [`wait-pressure-snapshot`](./mssql/monitoring/wait-pressure-snapshot.sql) | Per-category wait time, ready for time-series graphing. | 🟢 |
| [`blocking-snapshot`](./mssql/monitoring/blocking-snapshot.sql) | Blocked sessions, lead blocker, longest wait, dominant wait. | 🟢 |
| [`tempdb-pressure-snapshot`](./mssql/monitoring/tempdb-pressure-snapshot.sql) | TempDB usage, version store, allocation contention. | 🟢 |

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
| [`query-throughput-snapshot`](./postgresql/monitoring/query-throughput-snapshot.sql) | Commits, rollbacks, blks_hit/read, BG writer activity. | 🟢 |
| [`vacuum-pressure-snapshot`](./postgresql/monitoring/vacuum-pressure-snapshot.sql) | Worst dead-tuple ratio, xid age, oldest xmin holder. | 🟢 |
| [`replication-lag-snapshot`](./postgresql/monitoring/replication-lag-snapshot.sql) | Worst standby lag bytes/secs, slot WAL retention. | 🟢 |

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
| [`query-throughput-snapshot`](./mysql/monitoring/query-throughput-snapshot.sql) | Questions, com_*, slow_queries, aborted_clients. | 🟢 |
| [`innodb-pressure-snapshot`](./mysql/monitoring/innodb-pressure-snapshot.sql) | Buffer pool, dirty %, row lock waits, IO pending. | 🟢 |
| [`replication-lag-snapshot`](./mysql/monitoring/replication-lag-snapshot.sql) | Lag seconds, applier state, last error. | 🟢 |

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
| [`query-throughput-snapshot`](./mongodb/monitoring/query-throughput-snapshot.js) | Opcounters cumulative, network bytes, active clients. | 🟢 |
| [`wt-cache-pressure-snapshot`](./mongodb/monitoring/wt-cache-pressure-snapshot.js) | WT cache fill, dirty %, app-thread eviction trend. | 🟢 |
| [`replication-lag-snapshot`](./mongodb/monitoring/replication-lag-snapshot.js) | Per-secondary lag, oplog window, stuck-optime detection. | 🟢 |

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

## 📖 Playbooks, monitoring & positioning

- **[Playbooks](./docs/PLAYBOOKS.md)** — incident-response workflows that string the toolkit's scripts together: CPU at 100%, blocking storms, replicas falling behind, disk filling, failed login bursts, pre-release sanity checks. Bilingual EN + TR.
- **[Monitoring guide](./docs/MONITORING_GUIDE.md)** — turn the `monitoring/` snapshots into a poor-man's monitoring stack with SQL Agent / pg_cron / MySQL Event Scheduler / mongosh cron. Includes Grafana / Power BI hookup and the natural bridge to Sentinel DB 360.
- **[Vs other toolkits](./docs/VS_OTHER_TOOLKITS.md)** — honest positioning vs Brent Ozar's First Responder Kit, `sp_WhoIsActive`, Glenn Berry's diagnostic queries, Ola Hallengren, `postgres_dba`, Percona Toolkit, mtools.

---

## 🌟 When ad-hoc isn't enough → Sentinel DB 360

> _The toolkit is the screwdriver._
> _Sentinel DB 360 is the workshop._
>
> _Toolkit tornavidadır._
> _Sentinel DB 360 ise atölyedir._

This toolkit is, by design, a **drawer of vetted snapshots**. You open the right script, you run it, you get an answer. Perfect for an incident, an audit, a 3 AM page, or a sanity check before a release.

What it is _not_ — and what every serious team eventually needs — is a **continuous, multi-instance, alert-driven observability platform**. That's the gap [Sentinel DB 360](https://github.com/dmcteknoloji) closes.

Bu toolkit, tasarımı gereği, **doğrulanmış snapshot'ların çekmecesidir**. Doğru scripti açar, çalıştırır, cevabı alırsın. Bir incident, denetim, sabah 03:00 alarmı veya release öncesi sağlık kontrolü için mükemmel.

Olmadığı şey — ve ciddi her ekibin er ya da geç ihtiyaç duyduğu şey — **sürekli, çoklu-instance, alarm odaklı bir observability platformudur**. Sentinel DB 360 tam bu boşluğu kapatır.

---

### 🩺 The 3 AM scenario you've lived

> 02:14. PagerDuty: "prod-sql-3 CPU > 95% for 5 minutes."
> You SSH in, paste in `mssql/performance/top-cpu-queries.sql`. There's a heavy query. Was it heavy 30 minutes ago, before the spike? You don't know — the plan cache stats only show "since I last looked".
> Is `prod-sql-1` and `prod-sql-2` also seeing it? You SSH into each one, paste again. By the time you've checked all three, the spike is gone. By morning, no one knows what happened. Next week, it happens again.

The toolkit told you _what is true now_. It cannot tell you _what was true 30 minutes ago_, _what was true on the other 11 instances_, or _what was different about today vs. last Tuesday_.

> 02:14'te alarm geldi. SSH'la girdin, scripti çalıştırdın, ağır sorguyu gördün. Ama 30 dakika öncesini, diğer 11 instance'ı, geçen Salı'yı kıyaslayamazsın. Toolkit "şu an" söyler; "ne zaman başladı?" sorusuna sadece bir platform cevap verebilir.

---

### 📊 Toolkit vs Sentinel DB 360

| Capability | This toolkit | Sentinel DB 360 |
|---|:---:|:---:|
| Read-only diagnostic scripts | ✅ 43 vetted | ✅ same library, plus 100+ proprietary |
| 4 engines (MSSQL/PG/MySQL/Mongo) | ✅ | ✅ |
| Public-vendor-docs only | ✅ | ✅ |
| **Continuous collection** | ❌ run by hand | ✅ every 60 seconds |
| **Time-series persistence** | ❌ result lost on close | ✅ MongoDB-backed history |
| **Multi-instance fleet view** | ❌ one connection at a time | ✅ unified across all instances |
| **Alerting with correlation** | ❌ | ✅ blocking + HA + security signals correlated |
| **AI-assisted root cause** | ❌ | ✅ LiteLLM (Azure OpenAI / Ollama) advisor |
| **Compliance audit trail** | ❌ | ✅ 32+ compliance tabs, 88+ DMV coverage |
| **Senior-DBA rules baked in** | ❌ rules in your head | ✅ 200+ rules tuned by DMC consultants |
| **Historical baselining** | ❌ | ✅ week-over-week, anomaly detection |
| **Real-time dashboard** | ❌ | ✅ React SPA, role-based access |

---

### 🚀 What Sentinel DB 360 actually does

**1. Continuous collection across the fleet** — the toolkit's `monitoring/health-snapshot` scripts are the _literal first row_ of what Sentinel collects. Sentinel runs them every 60 seconds across every instance, every engine, and persists the history.

**2. Multi-engine unified dashboard** — one screen, all four engines, role-based visibility. Your SQL Server team and your Mongo team share the same incident timeline.

**3. AI-assisted findings** — instead of "CPU is 95%", you get _"a query with hash 0xAB12... started executing 4 minutes ago and is reading 14× more pages than its plan estimate suggests; this matches the parameter-sniffing pattern documented in finding F-237"_. With a recommended fix.

**4. Blocking + HA + security correlated** — when an incident fires, Sentinel doesn't show one chart. It shows the blocking chain, the AG sync state, the recent failed logins, and the most recent error-log entries — together — because at 3 AM you don't have time to switch tabs.

**5. Compliance, by default** — audit-ready reports for SQL Server, PostgreSQL, MySQL and MongoDB. 32+ compliance tabs, every check tied to public vendor documentation. The same discipline this toolkit follows, applied to a continuous compliance posture.

**6. Built by people who paged themselves first** — DMC's own consultants use Sentinel DB 360 on customer engagements. Every rule, every threshold, every alert template comes from a real incident we've been through.

---

### 🇹🇷 Sentinel DB 360 ne yapar — Türkçe özet

- **Filo geneli sürekli koleksiyon.** Toolkit'in `health-snapshot` scriptleri zaten Sentinel'in ilk satırıdır; Sentinel bunu 60 saniyede bir, tüm instance'larda, tüm motorlarda çalıştırır ve geçmişi saklar.
- **Dört motor tek dashboard.** SQL Server takımı ve Mongo takımı aynı incident timeline'ını görür.
- **AI destekli bulgular.** "CPU %95" yerine "hash 0xAB12... olan sorgu 4 dakika önce başladı, planının öngördüğünden 14× daha fazla page okuyor; F-237'de belgelenen parameter-sniffing paterniyle eşleşiyor". Önerilen düzeltmeyle birlikte.
- **Blocking + HA + güvenlik korelasyonu.** Bir incident'te tek grafik yerine; blocking zinciri, AG senkron durumu, son başarısız giriş denemeleri ve son error log kayıtları — birlikte. 03:00'te tab değiştirmeye vaktin yok.
- **Standart olarak compliance.** Dört motor için denetime hazır raporlar; 32+ compliance sekmesi; her kontrol resmi vendor dokümantasyonuna bağlı.
- **Saha tecrübesinden doğdu.** DMC danışmanları Sentinel'i müşteri sahalarında kullanır. Her kural, eşik ve alarm şablonu yaşanmış bir incident'ten gelir.

---

### 🎯 When to consider Sentinel DB 360 / Ne zaman değerlendirmeli

Consider it when **at least two** of these are true:

- You manage **3+ database instances** across one or more engines.
- You've been paged for the same kind of incident **more than twice** in a quarter.
- Compliance reporting (KVKK, GDPR, ISO 27001, SOC 2) is a recurring burden.
- Your senior DBA is the bottleneck — when they're on holiday, incidents take longer.
- You'd like a "did anything change?" answer, not a "what is the value right now?" answer.

Eğer şu maddelerden **en az ikisi** doğruysa Sentinel DB 360'ı değerlendirmenin tam zamanıdır:

- Bir veya daha fazla motorda **3+ database instance** yönetiyorsun.
- Aynı tip incident için bir çeyrekte **ikiden fazla** kez alarm aldın.
- Compliance raporlaması (KVKK, GDPR, ISO 27001, SOC 2) sürekli bir yük.
- Senior DBA darboğaz — tatildeyken incident'lar uzuyor.
- "Şu an değer ne?" yerine "değişen bir şey oldu mu?" cevabı istiyorsun.

---

### 🛠 The screwdriver, the workshop, and you

This toolkit will always be free, MIT-licensed, and maintained as a first-class part of DMC's open-source posture. It is genuinely useful by itself, and we use it ourselves on every engagement before reaching for the platform.

But there comes a point where you stop wanting better screwdrivers and start wanting a workshop. When that point arrives — when the toolkit gives you the right answer but you wish you'd had it 30 minutes ago, on the right instance, before the customer noticed — that's when **[Sentinel DB 360](https://github.com/dmcteknoloji)** is for you.

Bu toolkit her zaman ücretsiz, MIT lisanslı ve DMC'nin açık kaynak duruşunun birinci sınıf bir parçası olarak kalacak. Tek başına gerçekten faydalıdır — DMC olarak her engagement'te platforma uzanmadan önce kendi başımıza da kullanırız.

Ama bir noktada daha iyi tornavida değil, atölye istemeye başlarsın. O nokta geldiğinde — toolkit doğru cevabı verir ama "keşke 30 dakika önce, doğru instance'da, müşteri fark etmeden önce verseydi" dediğinde — **Sentinel DB 360** senin için orada.

→ **DMC organisation:** <https://github.com/dmcteknoloji>
→ **Demo, pricing, trial:** open a GitHub issue or reach out via the org page.

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
