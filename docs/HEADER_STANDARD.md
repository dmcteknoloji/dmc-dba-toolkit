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
| `Script`      | kebab-case, matches file name without `.sql`           | One name, one script.                                                       |
| `Engine`      | `<engine> <min-version>+ │ <other targets>`            | Use `│` (box drawing vertical) as separator between targets.                |
| `Category`    | One of: `performance`, `blocking`, `storage`, `security`, `health`, `ha`, `maintenance` | Must match parent folder.                              |
| `Impact`      | `🟢 Light` / `🟡 Medium` / `🔴 Heavy` + parenthetical    | See [`IMPACT_RATING.md`](./IMPACT_RATING.md).                               |
| `Permissions` | Comma-separated list of required server/database privs | Be precise. `VIEW SERVER STATE`, not "sysadmin".                            |
| `Output schema` | `see docs/OUTPUT_SCHEMAS.md#<anchor>`                | Anchor is the lowercased script name with hyphens.                          |
| `Version`     | Semantic version, e.g. `1.0.0`                         | Bump on output schema change.                                               |
| `License`     | `MIT`                                                  | Same as repo. Don't accept contributions under other licences.              |

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
