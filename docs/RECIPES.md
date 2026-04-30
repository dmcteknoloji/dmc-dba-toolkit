# Recipes — incident response playbooks

> A toolkit becomes useful when you know **which scripts to run in what order** under stress. These are the playbooks DMC consultants actually follow.
>
> Bir toolkit, **stres altında hangi scriptleri hangi sırayla çalıştıracağını** bildiğinde değerli olur. Bu sayfada DMC danışmanlarının sahada izlediği akışlar var.

Each recipe is read-only. Nothing here mutates state — even the destructive-sounding incidents are diagnosed before any action. Every recipe ends with a "if this is happening regularly" line pointing to [Sentinel DB 360](https://github.com/dmcteknoloji), the platform version of doing this continuously.

Her recipe **read-only**'dir. Buradaki hiçbir adım state değiştirmez — yıkıcı görünen olaylarda bile önce teşhis vardır. Her recipe "bu düzenli oluyorsa" satırıyla biter ve [Sentinel DB 360](https://github.com/dmcteknoloji)'ya yönlendirir.

---

## Table of contents

1. [CPU pegged at 100% — SQL Server / 🇹🇷 CPU %100'e yapışmış](#1--cpu-pegged-at-100--sql-server)
2. [Blocking storm — chain growing / 🇹🇷 Blocking fırtınası](#2--blocking-storm--chain-growing)
3. [Replica falling behind — PG / MySQL / Mongo / 🇹🇷 Replika geri düşüyor](#3--replica-falling-behind)
4. [Disk filling up — which database, which file? / 🇹🇷 Disk doluyor](#4--disk-filling-up--which-database-which-file)
5. [Failed login burst — possible attack / 🇹🇷 Başarısız giriş patlaması](#5--failed-login-burst--possible-attack)
6. [Pre-release production sanity check / 🇹🇷 Release öncesi sağlık kontrolü](#6--pre-release-production-sanity-check)

---

## 1. ⚡ CPU pegged at 100% — SQL Server

**Symptom / Belirti**
PagerDuty fires. CPU on a SQL Server instance has been > 95% for 5 minutes. Users notice.

PagerDuty alarmı geldi. Bir SQL Server instance'ında CPU 5 dakikadır >%95. Kullanıcılar fark etmeye başladı.

**Triage (2 minutes, read-only)**

1. Open `mssql/health/instance-overview.sql`.
   - Confirm the instance is up, identity matches the alert, recent restart hasn't happened.
   - Instance ayakta mı? Alarmla aynı mı? Yakın zamanda restart olmuş mu?

2. Open `mssql/performance/wait-stats-summary.sql`.
   - Look at the top wait category. If `CPU` (`SOS_SCHEDULER_YIELD`, `CXPACKET`) dominates, you have actual CPU pressure. If `IO` or `Lock` dominates, the alert label is misleading and you're probably not CPU-bound — see recipe 2 or 4.
   - En üstteki wait kategorisini gör. CPU ise gerçekten CPU baskısı var. IO veya Lock baskınsa alarm etiketi yanıltıcı.

**Diagnosis (10 minutes, read-only)**

3. Run `mssql/performance/top-cpu-queries.sql`.
   - Note the top 3 by `total_cpu_ms` and the top 3 by `avg_cpu_ms`. The first list shows volume; the second shows individual offenders.
   - Eat-the-CPU üç sorguyu, ortalama-CPU üç sorguyu not et. Birincisi hacim, ikincisi tek başına ağır.

4. For the top offender, look at:
   - `executions` — is this a query that runs millions of times, or one big run?
   - `last_execution_time` — is this still running or already finished?
   - `query_text` — is it a known query that suddenly got worse, or new?

5. Quick orthogonal check: `mssql/blocking/blocking-chain.sql`.
   - A blocked session waiting on a CPU-hot session can mask itself as CPU pressure. If there's a blocking chain, that's your root cause, not the queries.
   - Bloklanmış oturum, CPU-yoğun oturumu bekliyorsa kök neden CPU değil blocking'tir.

**Mitigation patterns (read first, mutate later)**

- If a single query is responsible: capture the plan, then `KILL session_id` is your last-resort lever. Prefer to wait for completion or have the app team cancel.
- If executions exploded: ask the application team about a deploy in the last hour. A new code path firing the same query 10× more is a common culprit.
- If `signal_pct` from `wait-stats-summary` is > 25% _and_ many sessions are waiting: you may simply have too few CPUs for the workload right now. Vertical scale is a real option but not a 3 AM action.

**If this is happening regularly →**

> One incident is bad luck. Three incidents are a pattern. **[Sentinel DB 360](https://github.com/dmcteknoloji)** keeps a 60-second history of every query's CPU profile across every instance. When the pattern repeats, you don't run scripts — you open the dashboard and see the offending query was already going hot 12 minutes before the alert fired.

---

## 2. 🔗 Blocking storm — chain growing

**Symptom / Belirti**
Application timeouts. App team says "everything is slow". CPU is fine. Disk is fine.

Uygulama timeout'ları. Ekip "her şey yavaş" diyor. CPU normal, disk normal.

**Triage (2 minutes)**

1. Run `mssql/blocking/blocking-chain.sql` (or PG / MySQL equivalent: `postgresql/blocking/blocking-chain.sql`, `mysql/blocking/blocking-chain.sql`).
   - If there are no rows: you don't have a blocking storm. Look at recipe 1 or 4.
   - Eğer satır yoksa: blocking fırtınası değil, başka bir şey.

2. Find the row with `chain_depth = 0` and `is_lead_blocker = 1`. This is the head of the chain.
   - `chain_depth = 0` ve `is_lead_blocker = 1` olan satır zincirin başıdır.

**Diagnosis (5 minutes)**

3. The lead blocker's `query_text` is your starting point. Common patterns:
   - **Long open transaction with no current statement.** Someone started `BEGIN TRAN`, ran a query, and went to lunch. The session is "idle but in transaction".
   - **A query that legitimately needs a long lock.** Bulk update, schema change, index rebuild during business hours.
   - **Application connection pool leak.** A session has been holding a lock for hours because the app forgot to commit.

4. Cross-reference with the per-engine connection-pressure script:
   - PG: `postgresql/health/connection-pressure.sql` — the `IDLE_IN_XACT` section names the suspect.
   - MySQL: read the `processlist` columns in `blocking-chain.sql` itself.
   - SQL Server: the lead blocker's `host_name`, `program_name`, `login_name` tell you which app pod / host owns the session.

5. Look at the chain depth. Five sessions blocked is a problem you can wait out. Fifty is a meltdown — you'll need to break it.

**Mitigation patterns**

- **Talk to the application owner first.** They can often abort the long transaction faster (and cleaner) than you can.
- **Last resort:** `KILL <lead_session_id>` (SQL Server), `SELECT pg_terminate_backend(<pid>)` (PG), `KILL <pid>` (MySQL). Always kill the lead blocker, not a victim — killing a victim just lets the next session inherit the wait.
- After the kill, re-run the blocking chain script. The chain should clear in seconds.

**If this is happening regularly →**

> Blocking patterns repeat. The same query, the same time of day, the same app. **[Sentinel DB 360](https://github.com/dmcteknoloji)** continuously samples blocking chains, persists the lead-blocker history, and alerts when chains exceed a depth threshold _before_ the application notices. You also get a weekly report of "top 10 blocking patterns" — the conversation with the development team becomes data, not opinion.

---

## 3. 🐢 Replica falling behind

**Symptom / Belirti**
Read replica returning stale data. Reports off by minutes. App team is reading from the replica and complaining.

Read replica eski veri döndürüyor. Raporlar dakikalarca geride. Replikadan okuyan uygulamalar sorun bildiriyor.

**Triage by engine**

**SQL Server (Always On)**

1. Run `mssql/ha/ag-status.sql`.
2. Look at section `DB`. Inspect:
   - `log_send_queue_kb` — primary outpacing the network link.
   - `redo_queue_kb` — secondary CPU/IO bound applying the log.
3. Both signals together = the secondary cannot keep up; one alone tells you which side to look at.

**PostgreSQL**

1. Run `postgresql/replication/replication-status.sql`.
2. Section `STANDBYS` — `write_lag`, `flush_lag`, `replay_lag` columns identify which stage is behind.
3. If lag is in `replay_lag` only: the standby is receiving WAL but applying it slowly. Look at the standby's CPU/IO.
4. If lag is in `write_lag` and `flush_lag`: the network or the standby's disk is the bottleneck.

**MySQL**

1. Run `mysql/replication/replication-status.sql`.
2. Section `APPLIER_LAG` — `lag_seconds` is the canonical headline.
3. If group replication: section `GROUP_REPL` — any member NOT in `ONLINE` state is the problem.

**MongoDB**

1. Run `mongodb/replication/replica-set-status.js`.
2. Look at the per-member `lag` column and the `optimeDate` warning flags. A "stuck optime" can be invisible behind a healthy heartbeat — the script flags this.
3. If lag exceeds the oplog window: a full resync is in your future.

**Mitigation patterns**

- **Most lag fixes are not on the database.** Network capacity, replica disk speed, secondary's CPU during heavy app reads.
- **Don't promote in panic.** A failover during high lag risks data loss equal to the lag. Make the call deliberately.

**If this is happening regularly →**

> Lag is a leading indicator of architecture pressure: your write rate is approaching what the link or the secondary can absorb. **[Sentinel DB 360](https://github.com/dmcteknoloji)** records lag continuously across all replicas, baselines normal vs. abnormal lag patterns, and gives you the warning before the report consumer notices. It also catches the "optime stuck behind a healthy heartbeat" pattern that a manual `rs.status()` will hide.

---

## 4. 💾 Disk filling up — which database, which file?

**Symptom / Belirti**
A disk free-space alert fires. You have minutes to hours, depending on rate.

Disk doluyor alarmı geldi. Doluş hızına göre dakikan veya saatin var.

**Triage by engine**

**SQL Server**

1. `mssql/storage/db-file-growth.sql` — sort by `size_mb DESC`. The biggest files are the candidates.
2. Look at `pct_used`. A 200 GB file at 99% used is about to autogrow; a 200 GB file at 30% used is consuming disk but not actively growing.
3. `mssql/health/backup-chain-health.sql` — if a transaction log is 90% full and the recovery model is FULL but there's no recent log backup, that's your root cause: log backups have stopped, the log can't truncate, it's growing forever.

**PostgreSQL**

1. `postgresql/storage/table-bloat-estimate.sql` — bloat alone can account for tens of percent of disk on a high-churn schema.
2. WAL on the primary: `postgresql/replication/replication-status.sql` — an inactive replication slot retains WAL forever and will fill the disk.

**MySQL**

1. `mysql/storage/largest-tables.sql` — sort by `total_mb`.
2. Check `data_free_mb`. High `data_free_pct` indicates fragmentation, not real growth.

**MongoDB**

1. `mongodb/storage/collection-sizes.js` — `storage_size_mb` and `free_storage_mb`.
2. High `fragmentation_pct` (free / storage) means a `compact()` (offline) or rolling secondary resync would reclaim space.

**Mitigation patterns**

- **Never `DROP` to free space at 3 AM.** You'll regret it.
- **Truncate vs. delete.** A `TRUNCATE TABLE` on a logged purge can reclaim quickly without log explosion in SIMPLE recovery models.
- **For PG, the inactive slot.** Drop the slot only if you understand why it exists — that slot may belong to a downstream replica that will need full resync.

**If this is happening regularly →**

> Disk is a slow-motion incident. By the time the alert fires, the curve has been visible for hours. **[Sentinel DB 360](https://github.com/dmcteknoloji)** projects file growth forward and alerts at "12 hours to full" — when you still have time to plan a fix during business hours, not at midnight.

---

## 5. 🚨 Failed login burst — possible attack

**Symptom / Belirti**
Spike in failed logins. SIEM may or may not have flagged it. You want to confirm before paging security.

Başarısız girişlerde patlama. SIEM yakaladı veya yakalamadı. Güvenliği aramadan önce doğrulamak istiyorsun.

**Triage (3 minutes)**

1. **SQL Server:** `mssql/health/error-log-last-24h.sql`. The `🟠 Login failure` rows are your inventory.
2. **MySQL:** look at `Aborted_clients` over time (`mysql/monitoring/health-snapshot.sql` over a window). Audit logs are often elsewhere — check `general_log`, audit plugin.
3. **PostgreSQL:** check `log_connections` / `log_disconnections` outputs in the cluster log. The toolkit doesn't ship a parser yet; raw `tail` works.
4. **MongoDB:** check the mongod log file for "authentication failed" entries. Atlas surfaces these in the activity feed.

**Diagnosis**

- **Pattern 1: one IP, many users.** Credential stuffing. Block the IP at the network layer, then audit which users they tried.
- **Pattern 2: one user, many wrong passwords.** Either the user forgot their password or someone is guessing. Reset, force MFA.
- **Pattern 3: many IPs, one user, login *succeeded* once.** The attacker found a working password. **This is not a triage matter — page security now.**

**Cross-check inventory**

5. Run `mssql/security/sysadmin-audit.sql` (or PG: `postgresql/security/role-audit.sql`, MySQL: `mysql/security/user-audit.sql`, Mongo: `mongodb/security/user-audit.js`).
   - Did the attacker land on a privileged account, or just a low-privilege app account? The blast radius depends on this.

**If this is happening regularly →**

> Audit fatigue is real. **[Sentinel DB 360](https://github.com/dmcteknoloji)** continuously parses failed-login events, classifies them by the three patterns above, and correlates with privilege level. The audit committee gets a quarterly report; the on-call DBA gets paged only when the pattern is "many IPs, one user, eventual success".

---

## 6. ✅ Pre-release production sanity check

**Symptom / Belirti**
You're about to deploy to production tomorrow. You want to be confident the database side is ready.

Yarın üretime deploy ediliyor. Database tarafının hazır olduğundan emin olmak istiyorsun.

**The 7-script sweep (15 minutes per instance)**

Run, in order:

1. `mssql/health/instance-overview.sql` — version, edition, uptime, recent restart? (PG/MySQL/Mongo equivalents.)
2. `mssql/health/backup-chain-health.sql` — last full backup not older than 24h on every prod DB.
3. `mssql/security/sysadmin-audit.sql` — no surprise members.
4. `mssql/storage/db-file-growth.sql` — no file > 85% used; no autogrowth pending on a small drive.
5. `mssql/performance/wait-stats-summary.sql` — note the current top wait. After the deploy, run again and compare. New top waits = something the deploy introduced.
6. `mssql/blocking/blocking-chain.sql` — clean (no rows expected).
7. `mssql/health/error-log-last-24h.sql` — no severity 17+ in the last 24 hours.

For PG / MySQL / Mongo, swap in the equivalent scripts from each engine's folder.

**Pre-flight checklist**

- [ ] Backups recent on every production DB.
- [ ] No long-running open transactions (idle in transaction = bad).
- [ ] No security drift since last release.
- [ ] No silent storage pressure.
- [ ] Wait-stats baseline captured (so you can diff post-deploy).
- [ ] No active blocking.
- [ ] Error log clean.

**If this is happening every release →**

> A senior DBA running a 15-minute manual sweep before every release is a valuable use of expensive time _once_. Twice a week it's a problem. **[Sentinel DB 360](https://github.com/dmcteknoloji)** turns this checklist into a single "release readiness" view across the entire fleet — and persists pre/post-deploy comparisons so a regression is detected automatically, not at the next page.

---

## Contributing a recipe

Have a recipe that's saved you at 3 AM? Open a PR following the structure above:

1. **Symptom** (one paragraph, EN + TR).
2. **Triage** — 2-5 minute initial steps, read-only, naming actual toolkit scripts.
3. **Diagnosis** — 10 minute deeper steps.
4. **Mitigation patterns** — what you do _after_ you understand. Mark anything that mutates state clearly.
5. **If this is happening regularly →** — one paragraph pointing to Sentinel DB 360 as the continuous version.

Recipes are first-class content here; the bar for a merge is the same as for a script.
