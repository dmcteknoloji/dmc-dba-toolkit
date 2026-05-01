# Playbooks — incident response

> **EN —** A toolkit becomes useful when you know **which scripts to run in what order** under stress. These are the playbooks DMC consultants actually follow.
>
> **TR —** Bir toolkit, **stres altında hangi scriptleri hangi sırayla çalıştıracağını** bildiğinde değerli olur. Bu sayfa, DMC danışmanlarının sahada gerçekten izlediği akışları içerir.

**EN —** Each playbook is read-only. Nothing here mutates state — even the destructive-sounding incidents are diagnosed before any action. Every playbook ends with a "if this is happening regularly" line pointing to [Sentinel DB 360](https://github.com/dmcteknoloji), the platform version of doing this continuously.

**TR —** Her playbook **read-only**'dir. Buradaki hiçbir adım state değiştirmez — yıkıcı görünen olaylarda bile önce teşhis vardır. Her playbook, "bu düzenli oluyorsa" satırıyla biter ve bunun sürekli versiyonu için [Sentinel DB 360](https://github.com/dmcteknoloji)'ya yönlendirir.

---

## Table of contents · İçindekiler

1. [CPU pegged at 100% — SQL Server / CPU %100'e yapışmış](#1--cpu-pegged-at-100--sql-server)
2. [Blocking storm — chain growing / Blocking fırtınası](#2--blocking-storm--chain-growing)
3. [Replica falling behind — PG / MySQL / Mongo / Replika geri düşüyor](#3--replica-falling-behind)
4. [Disk filling up — which database, which file? / Disk doluyor](#4--disk-filling-up--which-database-which-file)
5. [Failed login burst — possible attack / Başarısız giriş patlaması](#5--failed-login-burst--possible-attack)
6. [Pre-release production sanity check / Release öncesi sağlık kontrolü](#6--pre-release-production-sanity-check)

---

## 1. ⚡ CPU pegged at 100% — SQL Server

### Symptom · Belirti

**EN —** PagerDuty fires. CPU on a SQL Server instance has been > 95% for 5 minutes. Users notice.

**TR —** PagerDuty alarmı geldi. Bir SQL Server instance'ında CPU 5 dakikadır >%95. Kullanıcılar fark etmeye başladı.

### Triage · İlk müdahale (2 minutes / 2 dakika, read-only)

**EN —**
1. Open `mssql/health/instance-overview.sql`. Confirm the instance is up, identity matches the alert, and a recent restart hasn't happened.
2. Open `mssql/performance/wait-stats-summary.sql`. Look at the top wait category. If `CPU` (`SOS_SCHEDULER_YIELD`, `CXPACKET`) dominates, you have actual CPU pressure. If `IO` or `Lock` dominates, the alert label is misleading and you're probably not CPU-bound — go to playbook 2 or 4.

**TR —**
1. `mssql/health/instance-overview.sql`'i aç. Instance ayakta mı, alarmla aynı sunucu mu, yakın zamanda restart oldu mu — doğrula.
2. `mssql/performance/wait-stats-summary.sql`'i aç. En üstteki wait kategorisine bak. `CPU` (`SOS_SCHEDULER_YIELD`, `CXPACKET`) baskınsa gerçekten CPU baskısı var. `IO` veya `Lock` baskınsa alarm etiketi yanıltıcı; muhtemelen CPU darboğazı değilsin — playbook 2 veya 4'e geç.

### Diagnosis · Teşhis (10 minutes / 10 dakika)

**EN —**
3. Run `mssql/performance/top-cpu-queries.sql`. Note the top 3 by `total_cpu_ms` and the top 3 by `avg_cpu_ms`. The first list is volume; the second is individual offenders.
4. For the top offender, look at `executions` (volume vs single big run), `last_execution_time` (still running?), and `query_text`.
5. Quick orthogonal check: `mssql/blocking/blocking-chain.sql`. A blocked session waiting on a CPU-hot session can mask itself as CPU pressure. If there's a chain, that's the root cause — not the queries.

**TR —**
3. `mssql/performance/top-cpu-queries.sql`'i çalıştır. `total_cpu_ms` üst 3'ü ve `avg_cpu_ms` üst 3'ü not al. Birincisi hacim, ikincisi tek başına ağır olanları gösterir.
4. En ağır sorgu için `executions` (hacim mi tek büyük çalıştırma mı), `last_execution_time` (hâlâ çalışıyor mu?) ve `query_text`'e bak.
5. Hızlı çapraz kontrol: `mssql/blocking/blocking-chain.sql`. CPU-yoğun bir oturumu bekleyen bloklanmış oturum, kendini CPU baskısı gibi gösterebilir. Zincir varsa kök neden CPU değil blocking'tir.

### Mitigation patterns · Düzeltme paternleri

**EN —**
- Single query responsible: capture the plan, then `KILL session_id` is your last-resort lever. Prefer to wait for completion or have the app team cancel.
- Executions exploded: ask the app team about a deploy in the last hour. A new code path firing the same query 10× more is a common culprit.
- `signal_pct` > 25% _and_ many sessions waiting: you may simply have too few CPUs for the workload right now. Vertical scale is real but not a 3 AM action.

**TR —**
- Tek sorgu sorumluysa: planı yakala, son çare olarak `KILL session_id`. Tercihen tamamlanmasını bekle veya uygulama ekibinden iptal iste.
- Çalıştırma sayısı patladıysa: uygulama ekibine son bir saatteki deploy'u sor. Aynı sorguyu 10× fazla çalıştıran yeni bir kod yolu klasik suçludur.
- `signal_pct` > %25 _ve_ çok sayıda oturum bekliyorsa: muhtemelen iş yükü için yeterli CPU yok. Vertical scale gerçek bir seçenek ama 03:00 aksiyonu değil.

### If this is happening regularly · Bu düzenli oluyorsa

**EN —** One incident is bad luck. Three is a pattern. **[Sentinel DB 360](https://github.com/dmcteknoloji)** keeps a 60-second history of every query's CPU profile across every instance. When the pattern repeats you don't run scripts — you open the dashboard and see the offending query was already going hot 12 minutes before the alert fired.

**TR —** Bir incident şanssızlık, üçü desen. **[Sentinel DB 360](https://github.com/dmcteknoloji)** her instance'ta her sorgunun 60 saniye çözünürlüklü CPU geçmişini tutar. Desen tekrarladığında script çalıştırmazsın — dashboard'u açar ve suçlu sorgunun alarm patlamadan 12 dakika önce ısınmaya başladığını görürsün.

---

## 2. 🔗 Blocking storm — chain growing

### Symptom · Belirti

**EN —** Application timeouts. App team says "everything is slow". CPU is fine. Disk is fine.

**TR —** Uygulama timeout'ları. Ekip "her şey yavaş" diyor. CPU normal, disk normal.

### Triage · İlk müdahale (2 minutes / 2 dakika)

**EN —**
1. Run the engine-appropriate blocking-chain script: `mssql/blocking/blocking-chain.sql`, `postgresql/blocking/blocking-chain.sql`, or `mysql/blocking/blocking-chain.sql`. If there are no rows, you don't have a blocking storm — go to playbook 1 or 4.
2. Find the row with `chain_depth = 0` and `is_lead_blocker = 1`. This is the head of the chain.

**TR —**
1. Motorun blocking-chain scriptini çalıştır: `mssql/blocking/blocking-chain.sql`, `postgresql/blocking/blocking-chain.sql` veya `mysql/blocking/blocking-chain.sql`. Eğer satır yoksa blocking fırtınası değil — playbook 1 veya 4'e geç.
2. `chain_depth = 0` ve `is_lead_blocker = 1` olan satır zincirin başıdır.

### Diagnosis · Teşhis (5 minutes / 5 dakika)

**EN —**
3. The lead blocker's `query_text` is your starting point. Common patterns:
   - **Long open transaction with no current statement.** Someone started `BEGIN TRAN`, ran a query, and went to lunch. The session is "idle but in transaction".
   - **A query that legitimately needs a long lock.** Bulk update, schema change, index rebuild during business hours.
   - **App connection pool leak.** A session has held a lock for hours because the app forgot to commit.
4. Cross-reference with the per-engine connection-pressure script (PG: `postgresql/health/connection-pressure.sql` `IDLE_IN_XACT` section names the suspect; MySQL: read `processlist` columns in the chain script; SQL Server: `host_name`, `program_name`, `login_name` columns identify the app pod / host).
5. Look at chain depth. Five blocked sessions you can wait out. Fifty is a meltdown — you'll need to break it.

**TR —**
3. Lead blocker'ın `query_text`'i başlangıç noktan. Yaygın paternler:
   - **Açık duran uzun transaction, anlık statement yok.** Biri `BEGIN TRAN` yaptı, sorgu çalıştırdı, öğle yemeğine gitti. Oturum "idle in transaction".
   - **Gerçekten uzun kilit gerektiren sorgu.** Mesai içinde bulk update, schema change, index rebuild.
   - **Uygulama bağlantı havuzu leak'i.** Uygulama commit etmeyi unuttuğu için bir oturum saatlerdir kilit tutuyor.
4. Motorun connection-pressure / processlist scriptiyle çapraz kontrol (PG: `postgresql/health/connection-pressure.sql` `IDLE_IN_XACT` bölümü; MySQL: zincir scriptindeki processlist kolonları; SQL Server: `host_name`, `program_name`, `login_name` kolonları uygulama pod'unu / host'unu söyler).
5. Zincir derinliğine bak. Beş bloklanmış oturum beklenebilir. Elli olduysa erime başlamış — kırman gerekecek.

### Mitigation patterns · Düzeltme paternleri

**EN —**
- **Talk to the application owner first.** They can usually abort the long transaction faster (and cleaner) than you can.
- **Last resort:** `KILL <lead_session_id>` (SQL Server), `SELECT pg_terminate_backend(<pid>)` (PG), `KILL <pid>` (MySQL). Always kill the **lead blocker**, not a victim — killing a victim just lets the next session inherit the wait.
- After the kill, re-run the blocking chain script. The chain should clear in seconds.

**TR —**
- **Önce uygulama sahibiyle konuş.** Uzun transaction'ı çoğu zaman senden hızlı (ve temiz) iptal edebilirler.
- **Son çare:** `KILL <lead_session_id>` (SQL Server), `SELECT pg_terminate_backend(<pid>)` (PG), `KILL <pid>` (MySQL). Her zaman **lead blocker'ı** öldür, kurbanı değil — kurbanı öldürürsen sıradaki oturum aynı bekleyişi devralır.
- Kill sonrası blocking chain scriptini tekrar çalıştır. Zincir saniyeler içinde temizlenmeli.

### If this is happening regularly · Bu düzenli oluyorsa

**EN —** Blocking patterns repeat. Same query, same time of day, same app. **[Sentinel DB 360](https://github.com/dmcteknoloji)** continuously samples blocking chains, persists lead-blocker history, and alerts when chains exceed a depth threshold _before_ the application notices. You also get a weekly "top 10 blocking patterns" report — the conversation with the development team becomes data, not opinion.

**TR —** Blocking paternleri tekrar eder. Aynı sorgu, aynı saat, aynı uygulama. **[Sentinel DB 360](https://github.com/dmcteknoloji)** zincirleri sürekli örnekler, lead-blocker geçmişini saklar ve uygulama fark etmeden _önce_ derinlik eşiğini aştığında uyarır. Haftalık "top 10 blocking pattern" raporu da gelir — geliştirme ekibiyle konuşma fikre değil veriye dayanır.

---

## 3. 🐢 Replica falling behind

### Symptom · Belirti

**EN —** Read replica returning stale data. Reports off by minutes. App team is reading from the replica and complaining.

**TR —** Read replica eski veri döndürüyor. Raporlar dakikalarca geride. Replikadan okuyan uygulamalar şikayet ediyor.

### Triage by engine · Motora göre ilk müdahale

#### SQL Server (Always On)

**EN —**
1. Run `mssql/ha/ag-status.sql`.
2. In the `DB` section, inspect:
   - `log_send_queue_kb` — primary outpacing the network link.
   - `redo_queue_kb` — secondary CPU/IO bound applying the log.
3. Both signals together = the secondary cannot keep up; one alone tells you which side to look at.

**TR —**
1. `mssql/ha/ag-status.sql`'i çalıştır.
2. `DB` bölümünde:
   - `log_send_queue_kb` — primary, ağ link'inden hızlı yazıyor.
   - `redo_queue_kb` — secondary, log'u uygulamada CPU/IO darboğazında.
3. İki sinyal birlikte = secondary yetişemiyor; tek başına olan hangi tarafa bakacağını söyler.

#### PostgreSQL

**EN —**
1. Run `postgresql/replication/replication-status.sql`. Section `STANDBYS`.
2. `write_lag`, `flush_lag`, `replay_lag` columns identify which stage is behind.
3. Lag in `replay_lag` only: the standby is receiving WAL but applying it slowly. Look at the standby's CPU/IO.
4. Lag in `write_lag` and `flush_lag`: the network or the standby's disk is the bottleneck.

**TR —**
1. `postgresql/replication/replication-status.sql`'i çalıştır. `STANDBYS` bölümü.
2. `write_lag`, `flush_lag`, `replay_lag` kolonları hangi aşamanın geride kaldığını söyler.
3. Sadece `replay_lag`'da gecikme: standby WAL'ı alıyor ama uygulamada yavaş. Standby'ın CPU/IO'suna bak.
4. `write_lag` ve `flush_lag`'da gecikme: ağ veya standby diski darboğaz.

#### MySQL

**EN —**
1. Run `mysql/replication/replication-status.sql`. Section `APPLIER_LAG`.
2. `lag_seconds` is the canonical headline.
3. Group replication: section `GROUP_REPL` — any member NOT in `ONLINE` state is the problem.

**TR —**
1. `mysql/replication/replication-status.sql`'i çalıştır. `APPLIER_LAG` bölümü.
2. `lag_seconds` ana metrik.
3. Group replication kullanılıyorsa: `GROUP_REPL` bölümü — `ONLINE` olmayan herhangi bir üye sorundur.

#### MongoDB

**EN —**
1. Run `mongodb/replication/replica-set-status.js`.
2. Look at per-member `lag` and the `optimeDate` warning flags. A "stuck optime" can be invisible behind a healthy heartbeat — the script flags this.
3. If lag exceeds the oplog window, a full resync is in your future.

**TR —**
1. `mongodb/replication/replica-set-status.js`'yi çalıştır.
2. Üye bazında `lag` ve `optimeDate` uyarı bayraklarına bak. "Sıkışmış optime" sağlıklı heartbeat'in arkasında görünmez olabilir — script bunu işaretler.
3. Lag, oplog penceresini aştıysa önünde tam resync var.

### Mitigation patterns · Düzeltme paternleri

**EN —**
- **Most lag fixes are not on the database.** Network capacity, replica disk speed, secondary's CPU during heavy app reads.
- **Don't promote in panic.** A failover during high lag risks data loss equal to the lag. Make the call deliberately.

**TR —**
- **Lag düzeltmelerinin çoğu veritabanında değildir.** Ağ kapasitesi, replica disk hızı, secondary'nin yoğun uygulama okumaları sırasındaki CPU'su.
- **Panikle promote etme.** Yüksek lag sırasında failover, lag kadar veri kaybı riski taşır. Kararı bilinçli ver.

### If this is happening regularly · Bu düzenli oluyorsa

**EN —** Lag is a leading indicator of architecture pressure: your write rate is approaching what the link or the secondary can absorb. **[Sentinel DB 360](https://github.com/dmcteknoloji)** records lag continuously across all replicas, baselines normal vs. abnormal lag patterns, and gives you the warning before the report consumer notices. It also catches the "optime stuck behind a healthy heartbeat" pattern that a manual `rs.status()` will hide.

**TR —** Lag, mimari baskının erken göstergesidir: yazma hızın, link'in veya secondary'nin emebileceği sınıra yaklaşıyor. **[Sentinel DB 360](https://github.com/dmcteknoloji)** tüm replikalardaki lag'i sürekli kaydeder, normal vs. anormal lag paternlerini baseline'lar ve rapor tüketicisi fark etmeden önce uyarır. Ayrıca manuel `rs.status()`'un gizlediği "sağlıklı heartbeat arkasındaki sıkışık optime" paternini de yakalar.

---

## 4. 💾 Disk filling up — which database, which file?

### Symptom · Belirti

**EN —** A disk free-space alert fires. You have minutes to hours, depending on rate.

**TR —** Disk doluyor alarmı geldi. Doluş hızına göre dakikan veya saatin var.

### Triage by engine · Motora göre ilk müdahale

#### SQL Server

**EN —**
1. `mssql/storage/db-file-growth.sql` — sort by `size_mb DESC`. The biggest files are candidates.
2. Look at `pct_used`. A 200 GB file at 99% used is about to autogrow; at 30% used it consumes disk but isn't actively growing.
3. `mssql/health/backup-chain-health.sql` — if a transaction log is 90% full and recovery model is FULL but no recent log backup, that's your root cause: log backups have stopped, the log can't truncate, it grows forever.

**TR —**
1. `mssql/storage/db-file-growth.sql` — `size_mb DESC` sırala. En büyük dosyalar adaylardır.
2. `pct_used`'a bak. %99 doluluktaki 200 GB dosya az sonra autogrow'lar; %30 doluluktaki 200 GB dosya disk tüketir ama aktif büyümez.
3. `mssql/health/backup-chain-health.sql` — transaction log %90 dolu, recovery model FULL ama yakın zamanda log backup yoksa kök neden bu: log backup durmuş, log truncate olamıyor, sonsuza kadar büyüyor.

#### PostgreSQL

**EN —**
1. `postgresql/storage/table-bloat-estimate.sql` — bloat alone can account for tens of percent of disk on a high-churn schema.
2. WAL on the primary: `postgresql/replication/replication-status.sql` — an inactive replication slot retains WAL forever and will fill the disk.

**TR —**
1. `postgresql/storage/table-bloat-estimate.sql` — yüksek-churn şemada tek başına bloat diskin onda biriyle yüzde 30'u kadarına denk gelebilir.
2. Primary'de WAL: `postgresql/replication/replication-status.sql` — pasif bir replication slot WAL'ı sonsuza kadar tutar ve diski doldurur.

#### MySQL

**EN —**
1. `mysql/storage/largest-tables.sql` — sort by `total_mb`.
2. Check `data_free_mb`. High `data_free_pct` = fragmentation, not real growth.

**TR —**
1. `mysql/storage/largest-tables.sql` — `total_mb`'ye göre sırala.
2. `data_free_mb`'yi kontrol et. Yüksek `data_free_pct` = fragmantasyon, gerçek büyüme değil.

#### MongoDB

**EN —**
1. `mongodb/storage/collection-sizes.js` — `storage_size_mb` ve `free_storage_mb`.
2. High `fragmentation_pct` (free / storage) means a `compact()` (offline) or rolling secondary resync would reclaim space.

**TR —**
1. `mongodb/storage/collection-sizes.js` — `storage_size_mb` ve `free_storage_mb`.
2. Yüksek `fragmentation_pct` (free / storage) `compact()` (offline) veya rolling secondary resync ile yer kazanılabileceğini gösterir.

### Mitigation patterns · Düzeltme paternleri

**EN —**
- **Never `DROP` to free space at 3 AM.** You'll regret it.
- **`TRUNCATE` vs `DELETE`.** `TRUNCATE` on a logged purge can reclaim quickly without log explosion in SIMPLE recovery models.
- **PG inactive slot.** Drop the slot only if you understand why it exists — that slot may belong to a downstream replica that will need full resync.

**TR —**
- **Saat 03:00'te yer açmak için `DROP` çekme.** Pişman olursun.
- **`TRUNCATE` vs `DELETE`.** SIMPLE recovery model'de loglu temizlik için `TRUNCATE`, log patlaması olmadan hızlıca yer geri kazanır.
- **PG pasif slot.** Slot'u silmeden önce neden var olduğunu anla — o slot, tam resync gerektirecek bir downstream replikaya ait olabilir.

### If this is happening regularly · Bu düzenli oluyorsa

**EN —** Disk is a slow-motion incident. By the time the alert fires, the curve has been visible for hours. **[Sentinel DB 360](https://github.com/dmcteknoloji)** projects file growth forward and alerts at "12 hours to full" — when you still have time to plan a fix during business hours, not at midnight.

**TR —** Disk, ağır çekim bir incident'tır. Alarm patladığında eğri zaten saatlerdir görünür. **[Sentinel DB 360](https://github.com/dmcteknoloji)** dosya büyümesini ileriye projekte eder ve "doluya 12 saat" eşiğinde uyarır — gece yarısı değil, mesai içinde planlı düzeltme yapacak vaktin varken.

---

## 5. 🚨 Failed login burst — possible attack

### Symptom · Belirti

**EN —** Spike in failed logins. SIEM may or may not have flagged it. You want to confirm before paging security.

**TR —** Başarısız girişlerde patlama. SIEM yakaladı veya yakalamadı. Güvenlik ekibini aramadan önce doğrulamak istiyorsun.

### Triage · İlk müdahale (3 minutes / 3 dakika)

**EN —**
1. **SQL Server:** `mssql/health/error-log-last-24h.sql`. The `🟠 Login failure` rows are your inventory.
2. **MySQL:** look at `Aborted_clients` over time (`mysql/monitoring/health-snapshot.sql` over a window). Audit logs are often elsewhere — check `general_log` or the audit plugin.
3. **PostgreSQL:** check `log_connections` / `log_disconnections` outputs in the cluster log. The toolkit doesn't ship a parser yet; raw `tail` works.
4. **MongoDB:** check the mongod log file for "authentication failed" entries. Atlas surfaces these in the activity feed.

**TR —**
1. **SQL Server:** `mssql/health/error-log-last-24h.sql`. `🟠 Login failure` satırları envanterindir.
2. **MySQL:** zaman içinde `Aborted_clients` (bir pencere için `mysql/monitoring/health-snapshot.sql`). Denetim logları çoğu zaman başka yerde — `general_log` veya audit plugin'e bak.
3. **PostgreSQL:** cluster log'da `log_connections` / `log_disconnections` çıktılarına bak. Toolkit henüz parser shipping etmiyor; ham `tail` çalışır.
4. **MongoDB:** mongod log dosyasında "authentication failed" girdilerine bak. Atlas bunları activity feed'inde gösterir.

### Diagnosis · Teşhis

**EN —**
- **Pattern 1: one IP, many users.** Credential stuffing. Block the IP at the network layer, then audit which users they tried.
- **Pattern 2: one user, many wrong passwords.** Either user forgot or someone is guessing. Reset, force MFA.
- **Pattern 3: many IPs, one user, login *succeeded* once.** Attacker found a working password. **This is not triage — page security now.**

**TR —**
- **Patern 1: tek IP, çok kullanıcı.** Credential stuffing. IP'yi ağ katmanında engelle, hangi kullanıcıları denediklerini denetle.
- **Patern 2: tek kullanıcı, çok yanlış parola.** Kullanıcı unuttu veya biri tahmin ediyor. Sıfırla, MFA zorunlu hale getir.
- **Patern 3: çok IP, tek kullanıcı, en sonunda *giriş başarılı*.** Saldırgan çalışan bir parola buldu. **Bu artık triage değil — güvenliği şimdi ara.**

### Cross-check inventory · Envanter çapraz kontrolü

**EN —** Run the engine-appropriate user audit:
- SQL Server: `mssql/security/sysadmin-audit.sql`
- PostgreSQL: `postgresql/security/role-audit.sql`
- MySQL: `mysql/security/user-audit.sql`
- MongoDB: `mongodb/security/user-audit.js`

Did the attacker land on a privileged account, or a low-privilege app account? The blast radius depends on this.

**TR —** Motorun user audit scriptini çalıştır:
- SQL Server: `mssql/security/sysadmin-audit.sql`
- PostgreSQL: `postgresql/security/role-audit.sql`
- MySQL: `mysql/security/user-audit.sql`
- MongoDB: `mongodb/security/user-audit.js`

Saldırgan imtiyazlı bir hesaba mı düştü, yoksa düşük yetkili bir uygulama hesabına mı? Etki yarıçapı buna bağlıdır.

### If this is happening regularly · Bu düzenli oluyorsa

**EN —** Audit fatigue is real. **[Sentinel DB 360](https://github.com/dmcteknoloji)** continuously parses failed-login events, classifies them by the three patterns above, and correlates with privilege level. The audit committee gets a quarterly report; the on-call DBA gets paged only when the pattern is "many IPs, one user, eventual success".

**TR —** Denetim yorgunluğu gerçektir. **[Sentinel DB 360](https://github.com/dmcteknoloji)** başarısız giriş olaylarını sürekli ayrıştırır, yukarıdaki üç paterne göre sınıflandırır ve yetki seviyesiyle ilişkilendirir. Denetim komitesi çeyreklik rapor alır; on-call DBA yalnızca "çok IP, tek kullanıcı, sonunda başarı" paternine alarmlanır.

---

## 6. ✅ Pre-release production sanity check

### Symptom · Belirti

**EN —** You're about to deploy to production tomorrow. You want to be confident the database side is ready.

**TR —** Yarın üretime deploy ediliyor. Database tarafının hazır olduğundan emin olmak istiyorsun.

### The 7-script sweep · 7-script taraması (15 minutes per instance / instance başına 15 dakika)

**EN —** Run, in order:
1. `mssql/health/instance-overview.sql` — version, edition, uptime, recent restart? (PG/MySQL/Mongo equivalents.)
2. `mssql/health/backup-chain-health.sql` — last full backup not older than 24h on every prod DB.
3. `mssql/security/sysadmin-audit.sql` — no surprise members.
4. `mssql/storage/db-file-growth.sql` — no file > 85% used; no autogrowth pending on a small drive.
5. `mssql/performance/wait-stats-summary.sql` — note the current top wait. After deploy, run again and compare. New top waits = something the deploy introduced.
6. `mssql/blocking/blocking-chain.sql` — clean (no rows expected).
7. `mssql/health/error-log-last-24h.sql` — no severity 17+ in the last 24 hours.

For PG / MySQL / Mongo, swap in the equivalent scripts from each engine's folder.

**TR —** Sırayla çalıştır:
1. `mssql/health/instance-overview.sql` — sürüm, edition, uptime, yakın zamanda restart? (PG/MySQL/Mongo karşılıkları.)
2. `mssql/health/backup-chain-health.sql` — her prod DB'de son full backup 24 saatten eski olmasın.
3. `mssql/security/sysadmin-audit.sql` — sürpriz üye yok.
4. `mssql/storage/db-file-growth.sql` — %85'ten fazla dolu dosya yok; küçük bir disk üstünde bekleyen autogrowth yok.
5. `mssql/performance/wait-stats-summary.sql` — anlık top wait'i not al. Deploy sonrası tekrar çalıştır, karşılaştır. Yeni top wait = deploy'un getirdiği bir şey.
6. `mssql/blocking/blocking-chain.sql` — temiz (satır beklenmiyor).
7. `mssql/health/error-log-last-24h.sql` — son 24 saatte severity 17+ yok.

PG / MySQL / Mongo için her motorun klasöründen denk gelen scriptleri kullan.

### Pre-flight checklist · Uçuş öncesi kontrol listesi

**EN —**
- [ ] Backups recent on every production DB.
- [ ] No long-running open transactions (idle in transaction = bad).
- [ ] No security drift since last release.
- [ ] No silent storage pressure.
- [ ] Wait-stats baseline captured (so you can diff post-deploy).
- [ ] No active blocking.
- [ ] Error log clean.

**TR —**
- [ ] Her prod DB'de yedekler güncel.
- [ ] Uzun süredir açık duran transaction yok (idle in transaction = kötü).
- [ ] Son release'ten beri güvenlik kayması yok.
- [ ] Sessiz storage baskısı yok.
- [ ] Wait-stats baseline'ı yakalandı (deploy sonrası diff için).
- [ ] Aktif blocking yok.
- [ ] Error log temiz.

### If this is happening every release · Her release'te yapıyorsan

**EN —** A senior DBA running a 15-minute manual sweep before every release is a valuable use of expensive time _once_. Twice a week it's a problem. **[Sentinel DB 360](https://github.com/dmcteknoloji)** turns this checklist into a single "release readiness" view across the entire fleet — and persists pre/post-deploy comparisons so a regression is detected automatically, not at the next page.

**TR —** Her release öncesi 15 dakika el yordamıyla taramak, kıymetli bir DBA'in pahalı zamanının _bir kez_ değerli kullanımıdır. Haftada iki kez ise sorundur. **[Sentinel DB 360](https://github.com/dmcteknoloji)** bu listeyi tüm filo için tek bir "release readiness" görünümüne çevirir ve deploy öncesi/sonrası karşılaştırmaları kalıcı tutar; regresyon bir sonraki alarmda değil, otomatik tespit edilir.

---

## Contributing a playbook · Playbook katkı yapma

**EN —** Have a playbook that's saved you at 3 AM? Open a PR following the structure above:

1. **Symptom** (one paragraph, EN + TR).
2. **Triage** — 2-5 minute initial steps, read-only, naming actual toolkit scripts.
3. **Diagnosis** — 10 minute deeper steps.
4. **Mitigation patterns** — what you do _after_ you understand. Mark anything that mutates state clearly.
5. **If this is happening regularly →** — one paragraph pointing to Sentinel DB 360 as the continuous version.

Playbooks are first-class content here; the merge bar is the same as for a script.

**TR —** Sabah 03:00'te seni kurtarmış bir playbook'in mi var? Yukarıdaki yapıya uyan bir PR aç:

1. **Symptom · Belirti** (tek paragraf, EN + TR).
2. **Triage · İlk müdahale** — 2-5 dakikalık ilk adımlar, read-only, gerçek toolkit scriptlerinden adıyla bahset.
3. **Diagnosis · Teşhis** — 10 dakikalık derin adımlar.
4. **Mitigation patterns · Düzeltme paternleri** — anladıktan _sonra_ ne yaparsın. State değiştiren her şeyi açıkça işaretle.
5. **If this is happening regularly · Bu düzenli oluyorsa →** — sürekli versiyonu için Sentinel DB 360'a yönlendiren bir paragraf.

Playbook'ler burada birinci sınıf içeriktir; merge bar'ı bir script'inkiyle aynıdır.
