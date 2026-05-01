# Learning Paths · Öğrenme Yolları

> **EN —** This toolkit serves three audiences: DBAs in their first year, working DBAs with a few years of scar tissue, and senior practitioners. Pick your starting point.
>
> **TR —** Bu toolkit üç kitleyi besler: ilk yılındaki DBA'ler, birkaç yıllık iz birikmiş çalışan DBA'ler ve kıdemli pratisyenler. Başlangıç noktanı seç.

Every script is tagged with one of three levels in its header (`Level: 🌱 Newborn` / `🌳 Middle` / `🦅 Expert`). This page is the curriculum.

---

## 🌱 Newborn — your first month with a database

**EN —** Just got the keys to a database? Start here. Each script in this list ships with extensive bilingual commentary. Run them, read the comments, look at the output. By the end you'll know what DMVs / pg_stat / performance_schema / serverStatus actually are and how to ask "where am I and what is this?".

**TR —** Bir veritabanına yeni mi sahip oldun? Buradan başla. Bu listedeki her script bol bilingual yorum ile gelir. Çalıştır, yorumları oku, çıktıya bak. Sonunda DMV / pg_stat / performance_schema / serverStatus'un ne olduğunu ve "neredeyim ve bu nedir?" sorusunu nasıl soracağını bileceksin.

### The 8 Newborn-tier scripts

| # | Script | Question it answers |
|---|---|---|
| 1 | [`mssql/health/getting-started.sql`](../mssql/health/getting-started.sql) | What is a DMV? Where am I on this SQL Server? |
| 2 | [`mssql/health/instance-overview.sql`](../mssql/health/instance-overview.sql) | The polished one-screen instance summary. |
| 3 | [`mssql/health/backup-chain-health.sql`](../mssql/health/backup-chain-health.sql) | Are my backups recent? Recovery model right? |
| 4 | [`mssql/storage/db-file-growth.sql`](../mssql/storage/db-file-growth.sql) | How big are my files? Will autogrow fire soon? |
| 5 | [`mssql/monitoring/health-snapshot.sql`](../mssql/monitoring/health-snapshot.sql) | A one-row snapshot for cron + a target table. |
| 6 | [`postgresql/health/getting-started.sql`](../postgresql/health/getting-started.sql) | What is `pg_stat_*`? What does this cluster look like? |
| 7 | [`postgresql/health/instance-overview.sql`](../postgresql/health/instance-overview.sql) | One-screen PostgreSQL summary. |
| 8 | [`mysql/health/getting-started.sql`](../mysql/health/getting-started.sql) | System variables vs status variables — and where MySQL keeps each. |

(Mirror scripts exist for MongoDB — see [`mongodb/health/getting-started.js`](../mongodb/health/getting-started.js) and the `instance-overview` family per engine.)

### Recommended reading order · Önerilen okuma sırası

1. EN: Read your engine's `getting-started`. TR: Motorunun `getting-started`'ını oku.
2. Read `instance-overview` (the polished version of the same idea).
3. Read `backup-chain-health` (mssql) or its engine equivalent.
4. Run `monitoring/health-snapshot` and look at every column.

After that, you're ready to step up.

---

## 🌳 Middle — the working DBA

**EN —** You know what a DMV is. You've shipped a query plan. You've answered a 3 AM page. The Middle tier is the bulk of the toolkit (~40 scripts) — practical diagnostics with senior-DBA voice, production-grade SQL, and tight commentary. Run these on real workloads.

**TR —** DMV'nin ne olduğunu biliyorsun. Bir query plan'ı şıp diye okuyorsun. Sabah 3'teki alarmı kapattın. Middle tier, toolkit'in büyük kısmı (~40 script) — kıdemli DBA sesinde, production-grade SQL'le ve sıkı yorumlarla pratik tanı. Bunları gerçek workload'ler üzerinde çalıştır.

### Curated paths

#### Performance triage / Performans triajı
1. `mssql/performance/top-cpu-queries.sql`
2. `mssql/performance/missing-indexes.sql`
3. `mssql/blocking/blocking-chain.sql`
4. `postgresql/performance/top-queries.sql`
5. `postgresql/performance/unused-indexes.sql`
6. `mysql/performance/top-queries.sql`
7. `mysql/performance/innodb-row-lock-waits.sql`
8. `mongodb/performance/current-slow-ops.js`
9. `mongodb/performance/profiler-summary.js`

#### Storage / Depolama
1. `mssql/storage/db-file-growth.sql`
2. `mysql/storage/largest-tables.sql`
3. `mongodb/storage/collection-sizes.js`
4. (Expert →) `postgresql/storage/table-bloat-estimate.sql`

#### Security / Güvenlik
1. `mssql/security/sysadmin-audit.sql`
2. `mssql/security/tde-status.sql`
3. `mssql/security/orphaned-users.sql`
4. `postgresql/security/role-audit.sql`
5. `mysql/security/user-audit.sql`
6. `mongodb/security/user-audit.js`

#### Replication / Replikasyon
1. `mssql/ha/ag-status.sql`
2. `postgresql/replication/replication-status.sql`
3. `mysql/replication/replication-status.sql`
4. `mongodb/replication/replica-set-status.js`

After these, hit the [`docs/PLAYBOOKS.md`](./PLAYBOOKS.md) — six bilingual incident playbooks chaining the toolkit's scripts in workflow order.

---

## 🦅 Expert — the senior practitioner

**EN —** You've built monitoring. You've parsed deadlock graphs by hand. You know which DMV gets stale and when. The Expert tier is for you — multi-DMV joins, edge cases, and the kind of internals questions that normally need the vendor's reference open in a tab. The commentary assumes you already know the area.

**TR —** Monitoring kurmuşsun. Elle deadlock graph parse etmişsin. Hangi DMV'nin ne zaman bayatladığını biliyorsun. Expert tier senin için — çoklu-DMV join'leri, edge case'ler ve normalde vendor referansını açık tutmayı gerektiren internals soruları. Yorum, alanı zaten bildiğini varsayar.

### The 11 Expert-tier scripts

| # | Script | Why it's expert |
|---|---|---|
| 1 | [`mssql/blocking/deadlock-graph-parser.sql`](../mssql/blocking/deadlock-graph-parser.sql) | XML shredding the system_health Extended Events ring buffer. |
| 2 | [`mssql/performance/wait-stats-summary.sql`](../mssql/performance/wait-stats-summary.sql) | Categorised wait analysis with the benign-list philosophy. |
| 3 | [`mssql/monitoring/wait-pressure-snapshot.sql`](../mssql/monitoring/wait-pressure-snapshot.sql) | Wait-time time-series broken out by category. |
| 4 | [`mssql/monitoring/tempdb-pressure-snapshot.sql`](../mssql/monitoring/tempdb-pressure-snapshot.sql) | PFS / GAM / SGAM page latch contention. |
| 5 | [`postgresql/blocking/lock-mode-conflict-matrix.sql`](../postgresql/blocking/lock-mode-conflict-matrix.sql) | Lock-mode held × requested compatibility matrix. |
| 6 | [`postgresql/performance/wait-events-summary.sql`](../postgresql/performance/wait-events-summary.sql) | Wait-event interpretation + state-age stuck-session detection. |
| 7 | [`postgresql/storage/table-bloat-estimate.sql`](../postgresql/storage/table-bloat-estimate.sql) | Greg Sabino Mullane's bloat formula re-implemented. |
| 8 | [`postgresql/monitoring/vacuum-pressure-snapshot.sql`](../postgresql/monitoring/vacuum-pressure-snapshot.sql) | xmin holder + xid wraparound prediction. |
| 9 | [`mysql/performance/innodb-trx-deep.sql`](../mysql/performance/innodb-trx-deep.sql) | INNODB_TRX × data_locks × processlist deep cross-join. |
| 10 | [`mongodb/sharding/chunk-distribution.js`](../mongodb/sharding/chunk-distribution.js) | Hot-shard detection + jumbo chunks. |
| 11 | [`mongodb/performance/oplog-tailing-pattern.js`](../mongodb/performance/oplog-tailing-pattern.js) | Oplog window analysis — write-pattern decoding. |
| 12 | [`mongodb/monitoring/wt-cache-pressure-snapshot.js`](../mongodb/monitoring/wt-cache-pressure-snapshot.js) | WiredTiger app-thread eviction as the leading indicator. |

### When you're done with these

You're past what an open-source toolkit can give you. The next step is **continuous monitoring across a fleet** — that's [Sentinel DB 360](https://sentineldb360.com). The toolkit is the screwdriver; Sentinel DB 360 is the workshop.

Bunlarla işin bittiğinde, açık kaynak bir toolkit'in verebileceğinin ötesine geçmişsin. Bir sonraki adım **filo geneli sürekli izleme** — bu da [Sentinel DB 360](https://sentineldb360.com)'tır. Toolkit tornavida; Sentinel DB 360 ise atölye.

---

## How levels are decided / Seviyeler nasıl belirlenir

A script's level is determined by **the cognitive load to interpret its output**, not by its impact rating (🟢🟡🔴) or its query length:

- **🌱 Newborn**: Output reads itself. Anyone who knows what a database is can use it.
- **🌳 Middle**: Reader is expected to know what a DMV / catalog view / `serverStatus` is.
- **🦅 Expert**: Reader knows the area (deadlock graphs, WT internals, lock modes...). Comments don't re-explain the basics.

Bir scriptin seviyesi, çıktısını yorumlamak için gereken **bilişsel yük** ile belirlenir; impact rating (🟢🟡🔴) veya sorgu uzunluğu ile değil:

- **🌱 Newborn**: Çıktı kendini okur. Database nedir bilen herkes kullanabilir.
- **🌳 Middle**: Okuyucu DMV / catalog view / `serverStatus` nedir bilmeli.
- **🦅 Expert**: Okuyucu alanı zaten biliyor (deadlock graph, WT internals, lock mode...). Yorumlar temelleri tekrar anlatmaz.

The full reasoning lives in [`docs/HEADER_STANDARD.md#skill-levels`](./HEADER_STANDARD.md#skill-levels).
