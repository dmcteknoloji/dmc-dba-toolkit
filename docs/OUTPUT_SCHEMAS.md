# Output Schemas

Every column returned by every script in this toolkit is documented here. This is what makes downstream automation — dashboards, exports, monitoring pipelines — possible.

---

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

---

## wait-stats-summary

Aggregates `sys.dm_os_wait_stats` into meaningful categories with benign waits filtered out.

| Column              | Type            | Description                                                                                   |
| ------------------- | --------------- | --------------------------------------------------------------------------------------------- |
| `category`          | `nvarchar(64)`  | High-level wait category (CPU, IO, Lock, Latch, Memory, Network, Compilation, Other).        |
| `wait_type`         | `nvarchar(60)`  | Raw wait type from `sys.dm_os_wait_stats`.                                                    |
| `wait_time_sec`     | `decimal(18,2)` | Total wait time in seconds since instance startup or last `DBCC SQLPERF` reset.              |
| `pct_of_total`      | `decimal(5,2)`  | Percentage of total non-benign wait time this row represents.                                |
| `signal_wait_sec`   | `decimal(18,2)` | Time waiting for CPU after the wait condition was satisfied. High = CPU pressure.            |
| `signal_pct`        | `decimal(5,2)`  | `signal_wait_sec / wait_time_sec`. Above ~25% = look at CPU.                                 |
| `waiting_tasks`     | `bigint`        | Number of tasks that hit this wait type.                                                     |
| `avg_wait_ms`       | `decimal(18,2)` | Mean wait per task, in milliseconds.                                                         |

---

## blocking-chain

Returns the current blocking chain on the instance, with chain depth and lead-blocker identification.

| Column              | Type            | Description                                                                                   |
| ------------------- | --------------- | --------------------------------------------------------------------------------------------- |
| `chain_depth`       | `int`           | 0 for the lead blocker; 1, 2, ... for victims at each level.                                  |
| `is_lead_blocker`   | `bit`           | `1` for the head of a blocking chain; `0` otherwise.                                         |
| `session_id`        | `smallint`      | Session ID of this row.                                                                       |
| `blocking_session_id` | `smallint`    | Session blocking this one. `0` if not blocked.                                                |
| `wait_time_ms`      | `int`           | Time the session has been waiting on its current resource.                                    |
| `wait_type`         | `nvarchar(60)`  | Wait type (typically `LCK_M_*`).                                                              |
| `wait_resource`     | `nvarchar(256)` | Resource being waited on (e.g. `KEY: 7:72057594043236352 (...)`).                            |
| `database_name`     | `nvarchar(128)` | Database where the blocking is occurring.                                                     |
| `login_name`        | `nvarchar(128)` | Login that owns the session.                                                                  |
| `host_name`         | `nvarchar(128)` | Client host name.                                                                             |
| `program_name`      | `nvarchar(128)` | Application name.                                                                             |
| `query_text`        | `nvarchar(max)` | Currently executing batch text for the session.                                               |

---

## db-file-growth

Returns size, free space, and recent autogrowth pattern for every data and log file.

| Column                | Type            | Description                                                                                |
| --------------------- | --------------- | ------------------------------------------------------------------------------------------ |
| `database_name`       | `nvarchar(128)` | Database name.                                                                             |
| `file_type`           | `nvarchar(8)`   | `DATA` or `LOG`.                                                                           |
| `logical_name`        | `nvarchar(128)` | Logical file name as known to SQL Server.                                                  |
| `physical_path`       | `nvarchar(260)` | OS path of the file.                                                                       |
| `size_mb`             | `decimal(18,2)` | Current allocated file size, in megabytes.                                                 |
| `used_mb`             | `decimal(18,2)` | Used space within the file.                                                                |
| `free_mb`             | `decimal(18,2)` | Unused space within the file.                                                              |
| `pct_used`            | `decimal(5,2)`  | `used_mb / size_mb * 100`.                                                                 |
| `growth_setting`      | `nvarchar(32)`  | Autogrowth setting expressed as `+128 MB` or `+10%`.                                       |
| `max_size_mb`         | `decimal(18,2)` | Configured maximum size. `NULL` if unlimited.                                              |

---

## instance-overview

A one-screen summary of the SQL Server instance. Multi-section result set returned as one unioned table with a `section` discriminator column.

| Column           | Type            | Description                                                                                    |
| ---------------- | --------------- | ---------------------------------------------------------------------------------------------- |
| `section`        | `nvarchar(32)`  | Logical section: `IDENTITY`, `RESOURCES`, `UPTIME`, `WORKLOAD`, `BACKUPS`.                    |
| `metric`         | `nvarchar(64)`  | Name of the metric within the section.                                                         |
| `value`          | `nvarchar(256)` | Stringified value (e.g. `15.0.4360.2`, `64 GB`, `12d 04h 31m`).                              |
| `note`           | `nvarchar(256)` | Optional context (e.g. `last full backup is 8 days old — review`).                            |

This shape is intentional: a single result table, easy to dump, easy to compare across instances.
