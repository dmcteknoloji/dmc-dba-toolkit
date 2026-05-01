# Honors · Onur Listesi

> **EN —** This toolkit stands on a generation of public DBA writing, blogs, conference talks and open-source projects. The people listed below shaped how an entire discipline thinks about diagnostics. Where their public work measurably influenced a script in this repo, the script's `Inspired by` header field credits them by name. This page is the broader, ongoing roll of voices the maintainer follows and learns from.
>
> **TR —** Bu toolkit, bir kuşak DBA yazısının, bloğunun, konferans konuşmasının ve açık kaynak projesinin üzerinde duruyor. Aşağıda listelenen kişiler, koca bir disiplinin tanı yaklaşımını şekillendirdi. Public çalışmaları repo'daki bir scripte ölçülebilir biçimde etki ettiyse, ilgili scriptin `Inspired by` header alanı onları ismen kredi eder. Bu sayfa, maintainer'ın takip ettiği ve öğrenmeye devam ettiği daha geniş, sürekli güncel listedir.

The criteria for inclusion is simple: their **public** body of work made us measurably better at the craft. Some are recent voices; some published before "DBA" was a job title. We read them, we recommend them, we cite them.

Listeye girme kriteri basit: **public** çalışmaları bu zanaatta bizi ölçülebilir biçimde daha iyi yaptı. Bazıları yakın dönemden, bazıları "DBA" diye bir iş tanımı varolmadan önce yazmaya başlamış. Okuyoruz, öneriyoruz, atıf veriyoruz.

---

## 🟦 SQL Server

| Person / Project | What we learn | Where to find them |
|---|---|---|
| **Paul Randal & Kimberly Tripp** | Wait statistics methodology, internals deep dives, the canonical "benign waits" list. | [sqlskills.com](https://www.sqlskills.com) |
| **Brent Ozar & team** | First Responder Kit (`sp_Blitz`, `sp_BlitzFirst`, `sp_BlitzCache`), opinionated DBA tooling, weekly newsletter. | [brentozar.com](https://www.brentozar.com) · [github.com/BrentOzarULTD](https://github.com/BrentOzarULTD) |
| **Adam Machanic** | `sp_WhoIsActive` — the gold standard for active session diagnostics. 18+ years of one tool done right. | [github.com/amachanic/sp_whoisactive](https://github.com/amachanic/sp_whoisactive) |
| **Glenn Berry** | Monthly SQL Server Diagnostic Information Queries, deep DMV reference. | [glennsqlperformance.com](https://glennsqlperformance.com) |
| **Ola Hallengren** | Maintenance solution that an industry runs on — backup, integrity, indexes. | [ola.hallengren.com](https://ola.hallengren.com) |
| **Erik Darling** | Query store deep dives, plan analysis, derivative tooling for First Responder Kit. | [erikdarlingdata.com](https://erikdarlingdata.com) |
| **Kendra Little** | SQL Server education, training, deep articles on internals and performance. | [littlekendra.com](https://littlekendra.com) |
| **Itzik Ben-Gan** | T-SQL set theory, window functions, the books we all read on advanced T-SQL. | [tsql.solidq.com](https://tsql.solidq.com) |
| **Jonathan Kehayias** | Extended Events, Wait stats, deadlock graph parsing — public posts that shaped this toolkit. | SQLskills (above) |
| **Microsoft Tiger Team** | Internals posts, performance-tuning whitepapers, plan-cache deep dives. | [techcommunity.microsoft.com](https://techcommunity.microsoft.com) |
| **Aaron Bertrand** | Catalog DMV behaviour, T-SQL "Bad Habits to Kick" series, version-by-version differences. | [sqlblog.org](https://sqlblog.org) |

## 🟪 PostgreSQL

| Person / Project | What we learn | Where to find them |
|---|---|---|
| **PostgreSQL Global Development Group** | The official manual is itself a masterclass — every script in this repo cites it. | [postgresql.org/docs](https://www.postgresql.org/docs/) |
| **Greg Sabino Mullane** | Bloat estimation SQL on the Bucardo blog — credited in `table-bloat-estimate.sql`. Historical PG community contributor. | [bucardo.org](https://bucardo.org) |
| **Nikolay Samokhvalov** | `postgres_dba` — the structured psql menu of 34 reports. Postgres.AI, weekly Postgres newsletter. | [github.com/NikolayS/postgres_dba](https://github.com/NikolayS/postgres_dba) · [postgres.ai](https://postgres.ai) |
| **Bruce Momjian** | One of the original PG core developers; conference talks that explain PG internals to humans. | [momjian.us](https://momjian.us) |
| **Heikki Linnakangas** | PG core internals — WAL, replication, performance — public talks worth re-watching. | _PG mailing lists, Pgconf talks_ |
| **Robert Haas** | PG core architecture, parallel query, lock manager. Long-form blog posts. | [rhaas.blogspot.com](https://rhaas.blogspot.com) |
| **Robert Treat** | Postgres Open conference. Operational PostgreSQL knowledge. | _Postgres community_ |
| **Lukas Fittl** | pganalyze blog — query plans, autovacuum behaviour, performance investigation. | [pganalyze.com/blog](https://pganalyze.com/blog) |
| **Michael Christofides** | pgMustard — explain plan analysis. Postgres.FM podcast (with Nikolay). | [pgmustard.com](https://pgmustard.com) · [postgres.fm](https://postgres.fm) |

## 🟧 MySQL

| Person / Project | What we learn | Where to find them |
|---|---|---|
| **MySQL Reference Manual** | Cited from every MySQL script in this repo. The ground truth. | [dev.mysql.com/doc](https://dev.mysql.com/doc/) |
| **Percona engineers** | Percona Toolkit (`pt-query-digest`, `pt-online-schema-change`), the Percona Database Performance Blog, conference talks. | [percona.com/blog](https://www.percona.com/blog) · [github.com/percona](https://github.com/percona) |
| **Mark Callaghan** | Performance benchmarking at Facebook scale, MyRocks, deep public posts on InnoDB internals. | [smalldatum.blogspot.com](https://smalldatum.blogspot.com) |
| **Jeremy Cole** | InnoDB on-disk format dissected publicly, `innodb_ruby` library — definitive internals reference. | [github.com/jeremycole](https://github.com/jeremycole) |
| **Peter Zaitsev** | Co-founder of Percona, decades of MySQL operational depth. | [percona.com](https://www.percona.com) |
| **Baron Schwartz** | "High Performance MySQL" co-author, the book a generation of DBAs learned from. | [xaprb.com](https://xaprb.com) |
| **Justin Swanhart** | Common Schema, Flexviews — historical MySQL deep tooling. | _GitHub @greenlion_ |
| **Frédéric Descamps (LeFred)** | Oracle MySQL community manager — InnoDB Cluster, Group Replication explainers. | [lefred.be](https://lefred.be) |

## 🟩 MongoDB

| Person / Project | What we learn | Where to find them |
|---|---|---|
| **MongoDB Manual** | Cited from every MongoDB script. Comprehensive and well-maintained. | [mongodb.com/docs](https://www.mongodb.com/docs/) |
| **Asya Kamsky** | MongoDB aggregation pipeline mastery, public stage-by-stage explanations. | _MongoDB Inc., conference talks_ |
| **Kelly Stirman** | Early MongoDB advocacy and operational guidance, internals talks. | _MongoDB Inc._ |
| **Mathias Stearn** | MongoDB core engineer; replication and WiredTiger talks. | _MongoDB Inc., Engineering blog_ |
| **Henrik Ingo** | MongoDB performance team lead historically; HA and replication patterns. | _MongoDB Inc._ |
| **Tomas Rückstieß** | mtools — log parser and `mlaunch` test cluster tooling. | [github.com/rueckstiess/mtools](https://github.com/rueckstiess/mtools) |
| **idealo engineering** | mongodb-slow-operations-profiler — visualisation of slow ops. | [github.com/idealo](https://github.com/idealo) |

## 🌐 Cross-cutting / Database thinking

| Person / Project | What we learn | Where to find them |
|---|---|---|
| **Andy Pavlo (CMU Database Group)** | Free university-grade lectures on database internals — concurrency control, query optimisation, storage engines. The broader "why" behind everything in this toolkit. | [db.cs.cmu.edu](https://db.cs.cmu.edu) · [YouTube CMU DB Group](https://www.youtube.com/c/CMUDatabaseGroup) |
| **Martin Kleppmann** | "Designing Data-Intensive Applications" — the book that gives DBA work its broader systems frame. | [martin.kleppmann.com](https://martin.kleppmann.com) |
| **Use The Index, Luke** (Markus Winand) | The free online book everyone learning indexes should read. | [use-the-index-luke.com](https://use-the-index-luke.com) |
| **DBeaver / Erik Wramner / many others** | Tool authors, blog post authors, mailing-list answerers whose names we may not know but whose work shaped how we approach problems. | _the broader DBA web_ |

---

## 🇹🇷 Türkiye topluluğu / Turkey-based community

| Kişi / Topluluk | Ne öğreniriz | Nerede bulunur |
|---|---|---|
| **SQL Ekibi** | Türkçe SQL Server topluluğu — makaleler, eğitimler, konferanslar. DMC ailesinin parçası. | [sqlekibi.com](https://sqlekibi.com) |
| **Çağlar Özenç** | Bu toolkit'in maintainer'ı. Microsoft MVP — Data Platform. Konferans sunumları, blog. | [caglarozenc.com](https://caglarozenc.com) · [linkedin.com/in/caglarozenc](https://linkedin.com/in/caglarozenc) |
| **Türkiye Microsoft MVP topluluğu** | Yıllık MVP Summit içerikleri ve yerel etkinlikler — Türkiye'deki MVP'lerin hepsi takip listesinde. | _MVP topluluğu_ |

> _Bir isim eksik gördüysen — kişisel deneyimden bizi öğreten birini ekleyelim — issue aç ya da PR gönder. Bu sayfa kapalı bir liste değil, yaşayan bir teşekkür defteridir._

> _If you spot a name missing — someone whose public work taught the maintainer something — open an issue or PR. This page is not a closed list; it's a living thank-you ledger._

---

## How "Inspired by" works in headers · Header'da "Inspired by" nasıl çalışır

When a public source's specific technique shaped a script, the script's header carries an `Inspired by` line that names them. Examples already in the repo:

Bir public kaynağın spesifik tekniği bir scripti şekillendirdiğinde, ilgili scriptin header'ı onları ismen anan bir `Inspired by` satırı taşır. Repo'daki mevcut örnekler:

- `mssql/performance/wait-stats-summary.sql` → **Paul Randal (SQLskills)** — public Wait Statistics blog series, benign-wait list.
- `postgresql/storage/table-bloat-estimate.sql` → **Greg Sabino Mullane (Bucardo)** — bloat estimation SQL.
- `mssql/blocking/deadlock-graph-parser.sql` → **Jonathan Kehayias (SQLskills)** — public XE deadlock posts.

This is a deliberate practice. The DBA community has always been generous with knowledge; we credit out loud, every time.

Bu bilinçli bir uygulamadır. DBA topluluğu her zaman bilgisini cömertçe paylaşmıştır; biz her seferinde sesli teşekkür ederiz.

---

## A note on completeness · Eksiksizlik notu

This list is **not exhaustive**. It will never be — every working DBA has learned from people whose names they don't know, posts they read once and forgot the URL of, comments on Stack Overflow that fixed a Friday-evening incident. This page is what we can name with confidence and gratitude.

Bu liste **eksiksiz değildir**. Asla olmayacak — her çalışan DBA, ismini bilmediği insanlardan, bir kez okuyup URL'sini unuttuğu yazılardan, cuma akşamı bir vakayı kurtaran Stack Overflow yorumlarından öğrenmiştir. Bu sayfa, güvenle ve minnetle isim verebileceğimiz olanlardır.
