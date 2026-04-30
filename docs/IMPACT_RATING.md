# Impact Rating

Every script in this toolkit declares an impact rating in its header. This page is the authoritative definition.

## The three ratings

### 🟢 Light

- Pure DMV / catalog view scan.
- Sub-second to a few seconds on an idle instance.
- No plan cache pollution, no memory grants of consequence.
- **Safe to run on any production instance, any time.**

Examples: `top-cpu-queries`, `wait-stats-summary`, `instance-overview`.

### 🟡 Medium

- Touches multiple DMVs with joins, scans `sys.dm_db_index_usage_stats` or similar large structures.
- A few seconds to ~30s on a busy production instance.
- May cause transient memory grant pressure on small instances.
- **Fine on production, but don't loop it. Don't run during peak load on a struggling instance.**

Examples (planned): `index-usage-and-bloat`, `plan-cache-by-database`.

### 🔴 Heavy

- Touches plan cache iteratively, reads files via `sys.dm_io_virtual_file_stats` snapshots, runs `DBCC`-class operations, or scans the entire ring buffer.
- Tens of seconds to minutes; can move the needle on CPU/IO.
- **Run during a maintenance window or on a non-prod replica. Read the script before you run it.**

Examples (planned): `deadlock-graph-history`, `plan-handle-extraction`.

## How to assign a rating

When proposing a new script:

1. Estimate the worst case based on the DMVs/views you touch.
2. Run it on the largest test instance you can.
3. If unsure, **rate it one tier higher than you think.** Better to surprise users with how fast it is.

## What the rating is *not*

- It is not a measure of "how dangerous". Every script in this toolkit is read-only.
- It is not a measure of "how complex". A 10-line query against `sys.dm_os_ring_buffers` can be 🔴.

## Mutating scripts

This toolkit's main tree is **read-only by default**. Future destructive utilities (e.g. `kill-blocker`, `clear-plan-cache`, `rebuild-index`) will live in a `destructive_ops/` folder, with their impact tagged 🔴 *and* the header explicitly stating which state they mutate. They will require a `-- DMC: I-UNDERSTAND-THIS-MUTATES` sentinel comment to encourage deliberate use.

None ship in v1.0.
