# Header Standard

Every `.sql` file in this toolkit starts with the same header. This is the contract.

## The header

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
-- ║  Version       : 1.0.0                                           ║
-- ║  License       : MIT                                             ║
-- ╚══════════════════════════════════════════════════════════════════╝
```

## Required fields

| Field         | Format                                                 | Notes                                                                       |
| ------------- | ------------------------------------------------------ | --------------------------------------------------------------------------- |
| `Script`      | kebab-case, matches file name without `.sql` / `.js`   | One name, one script.                                                       |
| `Engine`      | `<engine> <min-version>+ │ <other targets>`            | Use `│` (box drawing vertical) as separator between targets.                |
| `Category`    | One of: `performance`, `blocking`, `storage`, `security`, `health`, `ha`, `replication`, `maintenance` | Must match parent folder.            |
| `Impact`      | `🟢 Light` / `🟡 Medium` / `🔴 Heavy` + parenthetical    | See [`IMPACT_RATING.md`](./IMPACT_RATING.md).                               |
| `Permissions` | Comma-separated list of required server/database privs | Be precise. `VIEW SERVER STATE`, not "sysadmin". For PG, list role/grants.  |
| `Output schema` | `see docs/OUTPUT_SCHEMAS.md#<anchor>`                | Anchor is the lowercased script name with hyphens.                          |
| `Version`     | Semantic version, e.g. `1.0.0`                         | Bump on output schema change.                                               |
| `License`     | `MIT`                                                  | Same as repo. Don't accept contributions under other licences.              |

## Optional fields

| Field          | Format                                              | When to use                                                          |
| -------------- | --------------------------------------------------- | -------------------------------------------------------------------- |
| `Level`        | `🌱 Newborn` / `🌳 Middle` / `🦅 Expert`              | Skill level the script targets — see **Skill levels** below.         |
| `Inspired by`  | `<Author / Project> — <topic, year>`                | When the technique (not the code) draws on a public source. Multiple sources separated by `;`. Always cite the public reference, not a private gist. |
| `Tested on`    | `<engine version, edition, platform>`               | When you've verified on a specific build and want to flag it.        |
| `Maintainer`   | `<Name> — <Org>`                                    | First maintainer of record for the script.                           |
| `Last updated` | `YYYY-MM-DD`                                        | Date the script's logic last changed in a meaningful way.            |

## Skill levels

The toolkit serves three audiences. Every script is tagged with the level it targets:

| Level | Symbol | Audience | Characteristics |
| --- | :---: | --- | --- |
| **Newborn** | 🌱 | DBAs in their first year — engineers, analysts, anyone newly responsible for a database. | Heavy bilingual commentary, a "what this is" preamble, output that's interpretable without prior DMV/catalog familiarity. Safe to run blind. |
| **Middle** | 🌳 | Working DBAs with 2-7 years of experience. The bulk of the toolkit. | Production-grade output, tight commentary, war-story flavour. Reader is expected to know what a DMV / catalog / `serverStatus` is. |
| **Expert** | 🦅 | Senior DBAs and consultants. | Multi-DMV joins, edge-case handling, deep-internals (deadlock graphs, plan handles, oplog tailing, lock mode conflict matrices). Comments assume reader knows the area. |

A script's level is **independent** of its impact rating (🟢🟡🔴). Impact = "is this safe to run on prod?". Level = "do you need senior knowledge to interpret the output?".

Find the right starting point by skill in [`docs/LEARNING_PATHS.md`](./LEARNING_PATHS.md).

## Sources policy (the line we don't cross)

This toolkit ships only what we can **legally and ethically** publish:

- **Public vendor documentation only.** Every system view, DMV, catalog table, profiler command and counter referenced in a script must be in the vendor's official, publicly accessible documentation (Microsoft Learn, postgresql.org, dev.mysql.com, mongodb.com/docs).
- **No NDA, no private previews, no scraped internal docs.** If the only place a query exists is behind an NDA, a closed beta, or someone's internal wiki — it does not ship here.
- **Inspiration is welcome, copying is not.** Acknowledge the public reference in `Inspired by`. Re-implement the technique in our own words. Do not paste code from sources whose license is incompatible with MIT.
- **Attribution is mandatory** when a public source clearly shaped the script. Even MIT/BSD-licensed inspirations get a credit line — not because the licence requires it, but because that's how a healthy community works.

This policy is restated, with examples, in [`CONTRIBUTING.md`](../CONTRIBUTING.md#attribution-and-sources-policy).

## Why box-art?

Two reasons:

1. **It's instantly recognisable.** Open any DMC script in any editor — you know what you're looking at within one screen.
2. **It's machine-parseable.** [`scripts/validate_headers.py`](../scripts/validate_headers.py) reads the field lines deterministically. No regex gymnastics.

## Editor support

The header characters are Unicode box drawing (`U+2554`, `U+2557`, `U+2560`, `U+2563`, `U+255A`, `U+255D`, `U+2550`, `U+2551`) plus `│` (`U+2502`).

Save files as UTF-8, no BOM. The `.editorconfig` enforces this.

## Versioning the script

Bump the script's `Version` field independently from the repository's release tag:

- **PATCH** — bug fix that doesn't change output schema.
- **MINOR** — new optional column, new `WHERE` filter parameter.
- **MAJOR** — column removed/renamed/retyped, behaviour change.

The repo tag (e.g. `v1.0.0`) reflects the toolkit as a whole. Individual script versions track their own evolution.
