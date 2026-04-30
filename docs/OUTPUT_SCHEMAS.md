# Output Schemas

Every column returned by every script in this toolkit is documented here. This is what makes downstream automation — dashboards, exports, monitoring pipelines — possible.

Anchors below match the `Output schema` field in each script header.

---

# 🟦 SQL Server

## top-cpu-queries

Returns the top resource-consuming queries currently in the plan cache, ranked by total worker time.

| Column                   | Type             | Description                                                                                  |
| ------------------------ | ---------------- | -------------------------------------------------------------------------------------------- |
| `rank`                   | `int`            | Position in the ranking (1 = highest CPU consumer).                                          |
| `query_hash`             | `binary(8)`      | Stable identifier for the normalized query text. Equal across plan recompiles.              |
| `executions`             | `bigint`         | Total executions of the query since plan cache entry was created.                            |
| `total_cpu_ms`           | `bigint`         | Cumulative CPU time across all executions, in milliseconds.                                  |
| `avg_cpu_ms`             | `decimal(18,2)`  | Mean CPU time per execution.                                                                 |
| `total_elapsed_ms`       | `bigint`         | Cumulative wall-clock duration.                                                              |
| `avg_elapsed_ms`         | `decimal(18,2)`  | Mean elapsed time per execution.                                                             |
| `total_logical_reads`    | `bigint`         | Cumulative logical page reads.                                                               |
| `avg_logical_reads`      | `bigint`         | Mean logical reads per execution.                                                            |
| `last_execution_time`    | `datetime`       | Timestamp of the most recent execution.                                                      |
| `database_name`          | `nvarchar(128)`  | Database the query was compiled against. May be `NULL` for ad-hoc queries.                  |
| `query_text`             | `nvarchar(max)`  | First 4000 chars of the query text. Sensitive literals are still present — handle with care. |

## wait-stats-summary

| Column              | Type            | Description                                                                                   |
| ------------------- | --------------- | --------------------------------------------------------------------------------------------- |
| `category`          | `nvarchar(64)`  | High-level wait category (CPU, IO, Lock, Latch, Memory, Network, Compilation, Other).        |
| `wait_type`         | `nvarchar(60)`  | Raw wait type from `sys.dm_os_wait_stats`.                                                    |
| `wait_time_sec`     | `decimal(18,2)` | Total wait time in seconds since instance startup or last `DBCC SQLPERF` reset.              |
| `pct_of_total`      | `decimal(5,2)`  | Percentage of total non-benign wait time this row represents.                                |
| `signal_wait_sec`   | `decimal(18,2)` | Time waiting for CPU after the wait condition was satisfied.                                 |
| `signal_pct`        | `decimal(5,2)`  | `signal_wait_sec / wait_time_sec`. Above ~25% = look at CPU.                                 |
| `waiting_tasks`     | `bigint`        | Number of tasks that hit this wait type.                                                     |
| `avg_wait_ms`       | `decimal(18,2)` | Mean wait per task, in milliseconds.                                                         |

## missing-indexes

| Column                  | Type             | Description                                                                                |
| ----------------------- | ---------------- | ------------------------------------------------------------------------------------------ |
| `rank`                  | `int`            | Position in the ranking by `impact_score`.                                                 |
| `database_name`         | `nvarchar(128)`  | Database the missing-index suggestion applies to.                                          |
| `schema_name`           | `nvarchar(128)`  | Schema of the target table.                                                                |
| `table_name`            | `nvarchar(128)`  | Target table.                                                                              |
| `user_seeks`            | `bigint`         | Number of seek operations the optimiser would have used the index for.                     |
| `user_scans`            | `bigint`         | Number of scans the optimiser would have used the index for.                               |
| `avg_total_user_cost`   | `decimal(18,2)`  | Average cost of operations that would benefit from this index.                             |
| `avg_user_impact_pct`   | `decimal(5,2)`   | Optimizer's estimate of the % cost reduction from the index.                               |
| `impact_score`          | `decimal(18,2)`  | `user_seeks * avg_total_user_cost * (avg_user_impact / 100)` — the canonical ranking.     |
| `last_user_seek`        | `datetime`       | Most recent time the optimiser would have used this index.                                |
| `equality_columns`      | `nvarchar(max)`  | Columns the optimiser wants for equality predicates.                                       |
| `inequality_columns`    | `nvarchar(max)`  | Columns the optimiser wants for range predicates.                                          |
| `included_columns`      | `nvarchar(max)`  | Columns the optimiser wants as `INCLUDE`.                                                  |

## blocking-chain

| Column                | Type            | Description                                                                                   |
| --------------------- | --------------- | --------------------------------------------------------------------------------------------- |
| `chain_depth`         | `int`           | 0 for the lead blocker; 1, 2, ... for victims at each level.                                 |
| `is_lead_blocker`     | `bit`           | `1` for the head of a blocking chain; `0` otherwise.                                         |
| `session_id`          | `smallint`      | Session ID of this row.                                                                       |
| `blocking_session_id` | `smallint`      | Session blocking this one. `0` if not blocked.                                                |
| `wait_time_ms`        | `int`           | Time the session has been waiting on its current resource.                                    |
| `wait_type`           | `nvarchar(60)`  | Wait type (typically `LCK_M_*`).                                                              |
| `wait_resource`       | `nvarchar(256)` | Resource being waited on.                                                                     |
| `database_name`       | `nvarchar(128)` | Database where the blocking is occurring.                                                     |
| `login_name`          | `nvarchar(128)` | Login that owns the session.                                                                  |
| `host_name`           | `nvarchar(128)` | Client host name.                                                                             |
| `program_name`        | `nvarchar(128)` | Application name.                                                                             |
| `query_text`          | `nvarchar(max)` | Currently executing batch text for the session.                                               |

## db-file-growth

| Column                | Type            | Description                                                                                |
| --------------------- | --------------- | ------------------------------------------------------------------------------------------ |
| `database_name`       | `nvarchar(128)` | Database name.                                                                             |
| `file_type`           | `nvarchar(8)`   | `DATA` or `LOG`.                                                                           |
| `logical_name`        | `nvarchar(128)` | Logical file name.                                                                         |
| `physical_path`       | `nvarchar(260)` | OS path of the file.                                                                       |
| `size_mb`             | `decimal(18,2)` | Current allocated file size, in megabytes.                                                 |
| `used_mb`             | `decimal(18,2)` | Used space within the file (NULL outside the current database in non-Azure mode).         |
| `free_mb`             | `decimal(18,2)` | Unused space within the file.                                                              |
| `pct_used`            | `decimal(5,2)`  | `used_mb / size_mb * 100`.                                                                 |
| `growth_setting`      | `nvarchar(32)`  | Autogrowth setting expressed as `+128 MB` or `+10%`.                                       |
| `max_size_mb`         | `decimal(18,2)` | Configured maximum size. `NULL` if unlimited.                                              |

## instance-overview

| Column           | Type            | Description                                                                                    |
| ---------------- | --------------- | ---------------------------------------------------------------------------------------------- |
| `section`        | `nvarchar(32)`  | `IDENTITY`, `RESOURCES`, `UPTIME`, `WORKLOAD`, `BACKUPS`.                                     |
| `metric`         | `nvarchar(64)`  | Name of the metric within the section.                                                         |
| `value`          | `nvarchar(256)` | Stringified value.                                                                             |
| `note`           | `nvarchar(256)` | Optional context (e.g. `last full backup is 8 days old — review`).                            |

---

# 🟪 PostgreSQL

## pg-top-queries

| Column             | Type      | Description                                                                          |
| ------------------ | --------- | ------------------------------------------------------------------------------------ |
| `rank`             | `bigint`  | Position by `total_exec_ms`.                                                         |
| `queryid`          | `bigint`  | Stable digest from `pg_stat_statements`.                                             |
| `database_name`    | `name`    | Database the query is associated with.                                               |
| `role_name`        | `name`    | Role that executed the query.                                                        |
| `calls`            | `bigint`  | Cumulative call count.                                                               |
| `total_exec_ms`    | `numeric` | Cumulative execution time in milliseconds.                                           |
| `avg_exec_ms`      | `numeric` | Mean execution time per call.                                                        |
| `min_exec_ms`      | `numeric` | Minimum execution time observed.                                                     |
| `max_exec_ms`      | `numeric` | Maximum execution time observed.                                                     |
| `stddev_exec_ms`   | `numeric` | Standard deviation. Useful to spot bimodal distributions (e.g. cache hit/miss).      |
| `total_rows`       | `bigint`  | Cumulative rows returned/affected.                                                   |
| `shared_blks_hit`  | `bigint`  | Buffer cache hits.                                                                   |
| `shared_blks_read` | `bigint`  | Buffer cache misses (read from OS / disk).                                           |
| `cache_hit_pct`    | `numeric` | `100 * hit / (hit + read)` — a quick "cold or warm" indicator per query.            |
| `query_preview`    | `text`    | First 200 chars of the (already normalized) query text.                              |

## pg-wait-events-summary

| Column                  | Type      | Description                                                       |
| ----------------------- | --------- | ----------------------------------------------------------------- |
| `wait_event_type`       | `text`    | Category (Lock, LWLock, IO, Client, Activity, ...). `CPU/Running` synthetic for non-waiting. |
| `wait_event`            | `text`    | Specific event name.                                              |
| `state`                 | `text`    | Backend state (`active`, `idle`, `idle in transaction`, ...).     |
| `sessions`              | `bigint`  | Sessions matching this combination.                               |
| `state_age_seconds_max` | `numeric` | Oldest age in this state — flags stuck sessions.                  |
| `databases`             | `text`    | Comma-separated list of databases involved.                       |
| `users`                 | `text`    | Comma-separated list of users.                                    |
| `applications`          | `text`    | Comma-separated list of `application_name`s.                      |

## pg-blocking-chain

| Column                | Type        | Description                                                                |
| --------------------- | ----------- | -------------------------------------------------------------------------- |
| `chain_depth`         | `integer`   | 0 for the lead blocker; 1, 2, ... for victims.                             |
| `is_lead_blocker`     | `boolean`   | `true` for chain heads.                                                    |
| `pid`                 | `integer`   | Backend PID.                                                               |
| `blocked_by_pid`      | `integer`   | Parent in the chain. `NULL` for lead blockers.                             |
| `database_name`       | `name`      | Database where the lock is.                                                |
| `user_name`           | `name`      | Backend user.                                                              |
| `application_name`    | `text`      | Application identifier from connection string.                             |
| `client_addr`         | `inet`      | Client IP.                                                                 |
| `state`               | `text`      | Backend state.                                                             |
| `wait_event_type`     | `text`      | Wait event category.                                                       |
| `wait_event`          | `text`      | Specific wait event.                                                       |
| `xact_age_seconds`    | `numeric`   | Age of the transaction.                                                    |
| `query_age_seconds`   | `numeric`   | Age of the current query within the transaction.                           |
| `query_preview`       | `text`      | First 300 chars of the current query.                                      |

## pg-table-bloat-est

| Column                | Type      | Description                                                                                |
| --------------------- | --------- | ------------------------------------------------------------------------------------------ |
| `schemaname`          | `name`    | Schema name.                                                                               |
| `tablename`           | `name`    | Table name.                                                                                |
| `actual_size`         | `text`    | On-disk size, pretty-printed.                                                              |
| `expected_size`       | `text`    | Estimated minimum size for the row count, pretty-printed.                                  |
| `estimated_bloat`     | `text`    | `actual − expected`, pretty-printed.                                                       |
| `bloat_pct`           | `numeric` | Bloat as a percentage of actual size.                                                      |
| `row_count_estimate`  | `numeric` | `pg_class.reltuples` — planner's estimate, accurate if `ANALYZE` was run recently.        |

## pg-replication-status

Single union-shaped table, sectioned by `section` discriminator.

| Column     | Type   | Description                                                                            |
| ---------- | ------ | -------------------------------------------------------------------------------------- |
| `section`  | `text` | `ROLE`, `STANDBYS`, or `SLOTS`.                                                        |
| `metric`   | `text` | Per-section: PRIMARY/STANDBY (ROLE), `application_name` (STANDBYS), `slot_name` (SLOTS). |
| `value`    | `text` | LSN string, lag string, or slot type + active flag.                                    |
| `note`     | `text` | Human-readable context, e.g. `inactive slot — retains WAL forever, can fill the disk`. |

## pg-instance-overview

| Column     | Type   | Description                                                  |
| ---------- | ------ | ------------------------------------------------------------ |
| `section`  | `text` | `IDENTITY`, `WORKLOAD`.                                      |
| `metric`   | `text` | Metric name within the section.                              |
| `value`    | `text` | Value as a string.                                           |
| `note`     | `text` | Optional context (e.g. autovacuum-off warning).              |

---

# 🟧 MySQL

## mysql-top-queries

| Column                    | Type        | Description                                                              |
| ------------------------- | ----------- | ------------------------------------------------------------------------ |
| `rank`                    | `bigint`    | Position by `total_latency_ms`.                                          |
| `query_digest`            | `varchar`   | Stable digest hash from `events_statements_summary_by_digest`.           |
| `schema_name`             | `varchar`   | Schema the digest was observed in.                                       |
| `executions`              | `bigint`    | `COUNT_STAR`.                                                            |
| `total_latency_ms`        | `decimal`   | Cumulative latency.                                                      |
| `avg_latency_ms`          | `decimal`   | Mean latency.                                                            |
| `min_latency_ms`          | `decimal`   | Minimum observed latency.                                                |
| `max_latency_ms`          | `decimal`   | Maximum observed latency.                                                |
| `total_rows_examined`     | `bigint`    | Sum of rows examined across executions.                                  |
| `avg_rows_examined`       | `bigint`    | Mean rows examined.                                                      |
| `total_rows_sent`         | `bigint`    | Sum of rows actually returned.                                           |
| `total_errors`            | `bigint`    | Errors raised across executions.                                         |
| `exec_no_index_used`      | `bigint`    | Executions where no index was used (full scan).                          |
| `exec_no_good_index_used` | `bigint`    | Executions where indexes existed but optimizer chose not to use them.    |
| `first_seen`, `last_seen` | `timestamp` | Window of observation.                                                   |
| `query_preview`           | `varchar`   | First 200 chars of normalized query text.                                |

## mysql-innodb-row-lock-waits

Multi-section result set; `section` discriminator.

| Column         | Type      | Description                                                            |
| -------------- | --------- | ---------------------------------------------------------------------- |
| `section`      | `varchar` | `CUMULATIVE` or `PER_TABLE`.                                           |
| `metric` / ... | `varchar` | In CUMULATIVE: status variable name. In PER_TABLE: schema/table/lock columns. |

## mysql-blocking-chain

| Column                  | Type      | Description                                              |
| ----------------------- | --------- | -------------------------------------------------------- |
| `wait_age_secs`         | `bigint`  | Seconds the waiter has been blocked.                     |
| `schema_name`           | `varchar` | Schema of the locked table.                              |
| `table_name`            | `varchar` | Table being contended on.                                |
| `index_name`            | `varchar` | Index where the lock is taken (NULL = row/gap on heap).  |
| `lock_type`             | `varchar` | `RECORD`, `TABLE`, etc.                                  |
| `waiting_pid`           | `bigint`  | Waiter process id.                                       |
| `waiting_query`         | `text`    | Query text the waiter is running.                        |
| `waiting_lock_mode`     | `varchar` | Mode requested.                                          |
| `blocking_pid`          | `bigint`  | Blocker process id.                                      |
| `blocking_query`        | `text`    | Query text of the blocker (NULL when blocker is idle).   |
| `blocking_lock_mode`    | `varchar` | Mode held.                                               |
| `waiting_host`, `waiting_user`, `blocking_host`, `blocking_user` | `varchar` | Connection identifiers from `processlist`. |

## mysql-largest-tables

| Column               | Type      | Description                                                              |
| -------------------- | --------- | ------------------------------------------------------------------------ |
| `rank`               | `bigint`  | Position by total_mb.                                                    |
| `schema_name`        | `varchar` | Schema name.                                                             |
| `table_name`         | `varchar` | Table name.                                                              |
| `engine`             | `varchar` | Storage engine (InnoDB, MyISAM, ...).                                    |
| `row_count_estimate` | `bigint`  | InnoDB sampled estimate; not exact.                                      |
| `data_mb`            | `decimal` | Data length in MB.                                                       |
| `index_mb`           | `decimal` | Index length in MB.                                                      |
| `total_mb`           | `decimal` | Sum of data + index.                                                     |
| `data_free_mb`       | `decimal` | Reported free space in the table's allocated segment.                    |
| `data_free_pct`      | `decimal` | `data_free / data * 100` — fragmentation proxy for InnoDB.              |
| `row_format`         | `varchar` | `Compact`, `Dynamic`, `Compressed`, ...                                  |
| `create_time`, `update_time` | `datetime` | Filesystem-level timestamps.                                    |

## mysql-replication-status

Multi-section: `CONNECTION`, `APPLIER`, `APPLIER_LAG`, `GROUP_REPL`. Each section uses the channel name as `metric` and packs state into `value` / `note`.

## mysql-instance-overview

| Column     | Type      | Description                                            |
| ---------- | --------- | ------------------------------------------------------ |
| `section`  | `varchar` | `IDENTITY`, `UPTIME`, `WORKLOAD`, `INNODB`.            |
| `metric`   | `varchar` | Metric within the section.                             |
| `value`    | `varchar` | Stringified value.                                     |
| `note`     | `varchar` | Optional context.                                      |

---

# 🟩 MongoDB

MongoDB scripts return JSON documents (printed via `printjson`). The schemas below describe the document shape, not a tabular column list.

## mongo-current-slow-ops

```
{
    opid:           number,
    secs_running:   number,
    microsecs_running: number,
    op:             "query" | "command" | "update" | "remove" | "getmore" | "insert",
    ns:             "<db>.<coll>",
    client:         string,
    appName:        string,
    desc:           string,
    currentOpTime:  ISODate,
    waitingForLock: boolean,
    numYields:      number,
    lockStats:      object,
    commandPreview: string  // first 400 chars
}
```

## mongo-profiler-summary

```
{
    ns:                 "<db>.<coll>",
    op:                 string,
    hasIndex:           boolean,
    samples:            number,
    total_millis:       number,
    avg_millis:         number,
    max_millis:         number,
    avg_keys_examined:  number,
    avg_docs_examined:  number,
    avg_nreturned:      number,
    example_planSummary: string
}
```

## mongo-replica-set-status

Printed as console output rather than a single document; key lines per member:

```
[id] host  state=PRIMARY|SECONDARY|...  health=1|0  uptime=Ns  lag=Ns  [⚠️ flag]
```

Plus an `oplog window` line (minutes), `oplog size`, and the election config table.

## mongo-index-usage

```
{
    collection:        string,
    index_name:        string,
    ops_since_reset:   number,
    counter_since:     ISODate,
    counter_age_hours: number,
    verdict:           "candidate-for-drop"
                     | "zero-but-counter-too-fresh"
                     | "low-usage"
                     | "active"
}
```

## mongo-collection-sizes

```
{
    collection:         string,
    document_count:     number,
    avg_doc_size_bytes: number,
    size_mb:            number,
    storage_size_mb:    number,
    index_size_mb:      number,
    free_storage_mb:    number,
    fragmentation_pct:  number,
    capped:             boolean,
    sharded:            boolean
}
```

## mongo-instance-overview

```
{
    IDENTITY: { version, gitVersion, modules, deployment, rs_role, host, os, cpu_arch },
    UPTIME:   { uptime_secs, local_time },
    WORKLOAD: { connections_current, connections_available, active_clients_total,
                op_inserts_per_sec, op_queries_per_sec, op_updates_per_sec,
                op_deletes_per_sec, opcounter_note },
    DATABASES:      { count, names },
    STORAGE_ENGINE: { name, supportsCommittedReads, readOnly }
}
```
