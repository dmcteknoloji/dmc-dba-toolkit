# Contributing to DMC DBA Toolkit

First — thank you. This toolkit only stays sharp if real DBAs stress-test it on real workloads.

This guide explains the bar for contributions and how to clear it without surprises.

---

## TL;DR

1. Open an issue first (or pick one labelled `good first script`).
2. Copy the header from any existing `.sql` file. Fill it in completely.
3. Run `python scripts/validate_headers.py` — must exit 0.
4. Run `sqlfluff lint .` — should be clean (warnings ok, errors not).
5. Document the output schema in [`docs/OUTPUT_SCHEMAS.md`](./docs/OUTPUT_SCHEMAS.md).
6. Add the script to [`docs/COMPATIBILITY_MATRIX.md`](./docs/COMPATIBILITY_MATRIX.md) and the README catalog.
7. Open a PR. CI will tell you the rest.

---

## Principles

These are not negotiable:

- **Read-only by default.** If your script mutates state (e.g. clears wait stats, kills sessions, rebuilds indexes), it goes in a future `destructive_ops/` folder, not the main tree, and its impact rating is 🔴 with the mutation behaviour described in plain English in the header.
- **One script, one question.** A script answers one DBA question (`who is blocking whom?`). Split anything that does two.
- **No deployment side effects.** No `CREATE PROCEDURE`, no `CREATE TABLE`, no objects left behind on the target instance. T-SQL queries only.
- **No `master`-binding.** Scripts must work in any database context.
- **Engine compatibility is part of the header.** Tested on the versions you list, no others.

---

## The Header Standard

Every `.sql` file starts with:

```sql
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  DMC DBA Toolkit                                                 ║
-- ╠══════════════════════════════════════════════════════════════════╣
-- ║  Script        : <kebab-case-name>                               ║
-- ║  Engine        : SQL Server <min-version>+ │ <other targets>     ║
-- ║  Category      : <performance|blocking|storage|security|health>  ║
-- ║  Impact        : 🟢 Light │ 🟡 Medium │ 🔴 Heavy + (one-line why) ║
-- ║  Permissions   : <required permissions, comma-separated>         ║
-- ║  Output schema : see docs/OUTPUT_SCHEMAS.md#<anchor>              ║
-- ║  Version       : <semver>                                        ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
```

Required fields: `Script`, `Engine`, `Category`, `Impact`, `Permissions`, `Output schema`, `Version`, `License`.

Full reference: [`docs/HEADER_STANDARD.md`](./docs/HEADER_STANDARD.md).

---

## Naming

- File names: `kebab-case.sql` — e.g. `blocking-chain.sql`, not `BlockingChain.sql`.
- Script `Script` field matches the file name (without `.sql`).
- Folder = category. Don't put a performance script in `health/`.

---

## Output schema

Every column the script returns must be documented in [`docs/OUTPUT_SCHEMAS.md`](./docs/OUTPUT_SCHEMAS.md):

```markdown
### top-cpu-queries

| Column          | Type     | Description                                          |
| --------------- | -------- | ---------------------------------------------------- |
| query_hash      | binary   | Stable identifier for the normalized query text.     |
| total_cpu_ms    | bigint   | Cumulative CPU time across all executions.           |
| ...             | ...      | ...                                                  |
```

This is what makes downstream automation (dashboards, exports, monitoring) possible.

---

## Pull request checklist

Copy this into your PR description:

```markdown
- [ ] New/changed `.sql` files all carry the standard header
- [ ] `python scripts/validate_headers.py` passes locally
- [ ] `sqlfluff lint <changed-files>` has no errors
- [ ] Output schema added/updated in docs/OUTPUT_SCHEMAS.md
- [ ] Compatibility matrix updated (docs/COMPATIBILITY_MATRIX.md + README)
- [ ] Tested on at least one of the engine versions claimed in the header
- [ ] CHANGELOG.md updated under [Unreleased]
```

---

## Testing claims

The header line `Engine: SQL Server 2019+` means **you actually ran it on 2019**. Don't speculate. If you only have 2022 access, write `SQL Server 2022 (other versions untested — please confirm)` and let the community fill in.

This honesty is the difference between a toolkit and a copy-paste graveyard.

---

## Code of Conduct

By participating, you agree to follow our [Code of Conduct](./CODE_OF_CONDUCT.md). Be excellent to each other. Disagree on technical grounds, never on personal ones.
