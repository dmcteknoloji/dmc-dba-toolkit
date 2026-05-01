# Monitoring Guide — turning snapshots into a poor-man's monitoring stack

> The toolkit's `monitoring/` scripts each return **one timestamped row** (or document) per execution. Schedule them every 30-60 seconds, sink the rows into a target table, and you have a real time-series for charts and alerts — without buying a platform.
>
> Toolkit'in `monitoring/` scriptleri her çalıştırmada **tek timestamped satır** (veya doküman) döner. 30-60 saniyede bir zamanla, satırları hedef tabloya yaz — grafik ve alarm için gerçek zaman serisi olur, platform almana gerek kalmadan.

This guide shows how to operationalise that.

---

## Table of contents · İçindekiler

1. [The 13 monitoring scripts](#the-13-monitoring-scripts)
2. [SQL Server — SQL Agent setup](#sql-server--sql-agent-setup)
3. [PostgreSQL — pg_cron / pgAgent setup](#postgresql--pg_cron--pgagent-setup)
4. [MySQL — Event Scheduler setup](#mysql--event-scheduler-setup)
5. [MongoDB — cron + mongosh setup](#mongodb--cron--mongosh-setup)
6. [Visualising — Grafana, Power BI, Sentinel](#visualising--grafana-power-bi-sentinel)
7. [When you outgrow this approach](#when-you-outgrow-this-approach)

---

## The 13 monitoring scripts

| Engine | Script | What it tracks |
|---|---|---|
| **SQL Server** | [`health-snapshot`](../mssql/monitoring/health-snapshot.sql) | CPU pressure, memory, sessions, throughput cumulative |
| **SQL Server** | [`query-throughput-snapshot`](../mssql/monitoring/query-throughput-snapshot.sql) | Batch req/sec, compilation/recompilation rates |
| **SQL Server** | [`wait-pressure-snapshot`](../mssql/monitoring/wait-pressure-snapshot.sql) | Per-category wait time (CPU, IO, Lock, Latch, ...) |
| **SQL Server** | [`blocking-snapshot`](../mssql/monitoring/blocking-snapshot.sql) | Blocked sessions, lead blocker, longest wait, dominant wait type |
| **SQL Server** | [`tempdb-pressure-snapshot`](../mssql/monitoring/tempdb-pressure-snapshot.sql) | TempDB usage, version store, allocation contention |
| **PostgreSQL** | [`health-snapshot`](../postgresql/monitoring/health-snapshot.sql) | Connections, transactions, cache hit, oldest xact, replication lag |
| **PostgreSQL** | [`query-throughput-snapshot`](../postgresql/monitoring/query-throughput-snapshot.sql) | Commits, rollbacks, blks_hit/read, BG writer activity |
| **PostgreSQL** | [`vacuum-pressure-snapshot`](../postgresql/monitoring/vacuum-pressure-snapshot.sql) | Worst dead-tuple ratio, xid age, oldest xmin holder |
| **PostgreSQL** | [`replication-lag-snapshot`](../postgresql/monitoring/replication-lag-snapshot.sql) | Worst standby lag bytes/secs, slot WAL retention |
| **MySQL** | [`health-snapshot`](../mysql/monitoring/health-snapshot.sql) | Connections, throughput cumulative, dirty pages, replica lag |
| **MySQL** | [`query-throughput-snapshot`](../mysql/monitoring/query-throughput-snapshot.sql) | Questions, com_*, slow_queries, aborted_clients |
| **MySQL** | [`innodb-pressure-snapshot`](../mysql/monitoring/innodb-pressure-snapshot.sql) | Buffer pool, dirty %, row lock waits, IO pending |
| **MySQL** | [`replication-lag-snapshot`](../mysql/monitoring/replication-lag-snapshot.sql) | Lag seconds, applier state, last error |
| **MongoDB** | [`health-snapshot`](../mongodb/monitoring/health-snapshot.js) | Connections, opcounters, RS role, WT cache |
| **MongoDB** | [`query-throughput-snapshot`](../mongodb/monitoring/query-throughput-snapshot.js) | Opcounters cumulative, network bytes, active clients |
| **MongoDB** | [`wt-cache-pressure-snapshot`](../mongodb/monitoring/wt-cache-pressure-snapshot.js) | Cache fill, dirty %, app-thread eviction (leading indicator) |
| **MongoDB** | [`replication-lag-snapshot`](../mongodb/monitoring/replication-lag-snapshot.js) | Per-secondary lag, oplog window, stuck-optime detection |

---

## SQL Server — SQL Agent setup

### 1. Create the target table

```sql
USE master;
GO

CREATE SCHEMA dmc_monitor;
GO

-- Generic catch-all using sql_variant for cross-script reuse, or a
-- typed table per snapshot. The typed approach is easier to query.
CREATE TABLE dmc_monitor.health_snapshot (
    sample_utc                  datetime2(3),
    server_name                 nvarchar(256),
    cpu_signal_wait_pct         decimal(5, 2),
    server_memory_mb            bigint,
    page_life_expectancy_secs   bigint,
    user_sessions               int,
    active_requests             int,
    blocked_sessions            int,
    active_transactions         int,
    batch_requests_cumulative   bigint,
    sql_compilations_cumulative bigint
);
GO
```

Repeat for the other four snapshot scripts (one table each).

### 2. Create a SQL Agent job

```sql
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'DMC monitoring — health snapshot';

EXEC sp_add_jobstep
    @job_name = N'DMC monitoring — health snapshot',
    @step_name = N'INSERT into health_snapshot',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @command = N'
        INSERT INTO master.dmc_monitor.health_snapshot
        EXEC ('' /* paste the contents of mssql/monitoring/health-snapshot.sql */ '');
    ';

EXEC sp_add_schedule
    @schedule_name = N'every minute',
    @freq_type = 4,                  -- daily
    @freq_interval = 1,
    @freq_subday_type = 4,           -- minutes
    @freq_subday_interval = 1;

EXEC sp_attach_schedule
    @job_name = N'DMC monitoring — health snapshot',
    @schedule_name = N'every minute';
```

Repeat for each snapshot. **On Azure SQL Database** (single), use Elastic Jobs or Logic Apps instead of SQL Agent.

### 3. Retention

A 1-minute schedule produces 1440 rows/day per table. After 90 days you have ~130k rows — small. Add an index on `sample_utc DESC` and a nightly purge job:

```sql
DELETE FROM master.dmc_monitor.health_snapshot
WHERE sample_utc < DATEADD(DAY, -90, GETUTCDATE());
```

---

## PostgreSQL — pg_cron / pgAgent setup

### 1. Create the schema and target table

```sql
CREATE SCHEMA IF NOT EXISTS dmc_monitor;

CREATE TABLE dmc_monitor.health_snapshot (
    sample_utc        timestamptz,
    server_addr       inet,
    database_name     text,
    conn_total        bigint,
    conn_active       bigint,
    conn_idle_in_xact bigint,
    max_connections   int,
    -- ... add the remaining columns to match the script's output schema
    PRIMARY KEY (sample_utc)
);
```

### 2. Schedule with `pg_cron`

```sql
-- Requires the pg_cron extension (RDS, Aurora, Cloud SQL all support it).
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'dmc-health-snapshot',          -- job name
    '* * * * *',                    -- every minute
    $$
    INSERT INTO dmc_monitor.health_snapshot
    /* paste the contents of postgresql/monitoring/health-snapshot.sql */
    $$
);
```

### 3. Retention

```sql
SELECT cron.schedule(
    'dmc-monitor-purge',
    '15 2 * * *',                   -- 02:15 daily
    $$
    DELETE FROM dmc_monitor.health_snapshot
    WHERE sample_utc < now() - interval '90 days';
    $$
);
```

---

## MySQL — Event Scheduler setup

### 1. Enable Event Scheduler

```sql
SET GLOBAL event_scheduler = ON;
```

### 2. Create the target table and event

```sql
CREATE DATABASE IF NOT EXISTS dmc_monitor;

CREATE TABLE dmc_monitor.health_snapshot (
    sample_utc      DATETIME(6),
    hostname        VARCHAR(255),
    threads_connected BIGINT,
    threads_running   BIGINT,
    questions_cumulative BIGINT,
    -- ... add the remaining columns
    PRIMARY KEY (sample_utc)
) ENGINE=InnoDB;

DELIMITER //
CREATE EVENT dmc_monitor.health_snapshot_event
    ON SCHEDULE EVERY 1 MINUTE
    DO
BEGIN
    INSERT INTO dmc_monitor.health_snapshot
    /* paste the contents of mysql/monitoring/health-snapshot.sql */
    ;
END //
DELIMITER ;
```

### 3. Retention

```sql
DELIMITER //
CREATE EVENT dmc_monitor.health_snapshot_purge
    ON SCHEDULE EVERY 1 DAY STARTS '2026-05-01 02:15:00'
    DO
BEGIN
    DELETE FROM dmc_monitor.health_snapshot
    WHERE sample_utc < NOW() - INTERVAL 90 DAY;
END //
DELIMITER ;
```

---

## MongoDB — cron + mongosh setup

### 1. Create the target collection (capped is overkill at 1-min cadence)

```javascript
use dmc_monitor;
db.createCollection("health_snapshot");
db.health_snapshot.createIndex({ sample_utc: -1 });
```

### 2. cron entry on the host

```cron
# every minute, append the snapshot to dmc_monitor.health_snapshot
* * * * * /usr/bin/mongosh "<connection-uri>" --quiet --eval "
  const snap = (function(){ /* paste script body */ })();
  db.getSiblingDB('dmc_monitor').health_snapshot.insertOne(snap);
"
```

For Atlas, use **Triggers** (Database → Triggers) instead of host cron.

### 3. Retention — TTL index

```javascript
// Auto-delete documents older than 90 days
db.getSiblingDB("dmc_monitor").health_snapshot.createIndex(
    { sample_utc: 1 },
    { expireAfterSeconds: 90 * 24 * 60 * 60 }
);
```

---

## Visualising — Grafana, Power BI, Sentinel

### Grafana

1. Add the database as a data source (PostgreSQL, MySQL, MS SQL — all native plugins).
2. Create a panel with this query (PostgreSQL example):

```sql
SELECT
    sample_utc AS time,
    cache_hit_pct AS cache_hit_pct
FROM dmc_monitor.health_snapshot
WHERE sample_utc > now() - interval '24 hours'
ORDER BY sample_utc;
```

For MongoDB, point Grafana's MongoDB plugin at `dmc_monitor.health_snapshot`.

### Power BI

DirectQuery to the database; the snapshot tables work directly.

### Sentinel DB 360

If you've gotten this far and you're enjoying the dashboards but the operational overhead is starting to bite, that's exactly what [Sentinel DB 360](https://sentineldb360.com) automates. It collects this same shape of data continuously, persists it, baselines it, and surfaces anomalies — without a single SQL Agent job, pg_cron schedule, or mongosh cron entry.

---

## When you outgrow this approach

This guide gets you to ~5 instances, ~6 metrics each, with manual graphing. Beyond that:

- **Adding a new metric means editing a CREATE TABLE on every instance.** Brittle.
- **Cross-instance correlation requires you to write joins on snapshot tables.** Tedious.
- **Alerting is left to the visualisation tool** (Grafana alerts, Power BI alerts) — works but is detached from the data ingestion side.
- **Anomaly detection ("this is 3σ outside normal")** is not in scope here. You'd need to roll your own statistics on top.

This is the natural moment to look at [Sentinel DB 360](https://sentineldb360.com), which solves all four of those at the platform level.

> _The toolkit is the screwdriver._
> _Sentinel DB 360 is the workshop._

Bu rehber ~5 instance, motor başına ~6 metric, manuel grafik düzeyine getirir. Bunun ötesinde — yeni metric eklemek her instance'ta CREATE TABLE düzenlemek demek (kırılgan), cross-instance korelasyon snapshot tablolarında join yazmak demek (sıkıcı), alarm görselleştirme tarafına taşınır (kopuk), anomali tespiti ("normalden 3σ uzakta") burada kapsamda değil. Sentinel DB 360'ı düşünmenin doğal noktası budur.
