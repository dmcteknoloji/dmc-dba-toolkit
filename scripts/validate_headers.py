#!/usr/bin/env python3
"""Validate that every .sql file in the repository carries the standard DMC header.

Usage
-----
    python scripts/validate_headers.py
    python scripts/validate_headers.py path/to/specific.sql

Exit codes
----------
    0   all headers valid
    1   one or more files have missing or malformed headers
    2   tooling error (e.g. file unreadable)

The standard header is documented in docs/HEADER_STANDARD.md.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_FIELDS = (
    "Script",
    "Engine",
    "Category",
    "Impact",
    "Permissions",
    "Output schema",
    "Version",
    "License",
)

VALID_CATEGORIES = {
    "performance",
    "blocking",
    "storage",
    "security",
    "health",
    "ha",
    "replication",
    "sharding",
    "monitoring",
    "maintenance",
}

VALID_IMPACTS = ("🟢 Light", "🟡 Medium", "🔴 Heavy")

# Match a line like:
#   -- ║  Script        : top-cpu-queries                  ║   (SQL files)
#   // ║  Script        : current-slow-ops                 ║   (mongosh .js files)
FIELD_LINE = re.compile(
    r"^(?:--|//)\s*║\s*(?P<key>[A-Za-z][A-Za-z ]+?)\s*:\s*(?P<value>.+?)\s*║\s*$"
)

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def parse_header(path: Path) -> dict[str, str] | None:
    """Return a dict of the header fields, or None if no header was found."""
    try:
        with path.open("r", encoding="utf-8") as fh:
            lines = [next(fh, "") for _ in range(40)]
    except OSError as exc:  # pragma: no cover
        print(f"::error file={path}::cannot read: {exc}", file=sys.stderr)
        sys.exit(2)

    fields: dict[str, str] = {}
    for line in lines:
        m = FIELD_LINE.match(line.rstrip("\n"))
        if m:
            fields[m.group("key").strip()] = m.group("value").strip()
    return fields or None


def validate(path: Path) -> list[str]:
    """Return a list of human-readable problems with this file's header."""
    fields = parse_header(path)
    if fields is None:
        return ["no DMC header found in the first 40 lines"]

    problems: list[str] = []

    for required in REQUIRED_FIELDS:
        if required not in fields:
            problems.append(f"missing field: {required!r}")

    script = fields.get("Script", "")
    expected = path.stem  # works for both .sql and .js
    if script and script != expected:
        problems.append(
            f"Script field {script!r} does not match file name {expected!r}"
        )

    category = fields.get("Category", "").lower()
    if category and category not in VALID_CATEGORIES:
        problems.append(
            f"Category {category!r} not in {sorted(VALID_CATEGORIES)}"
        )

    parent = path.parent.name.lower()
    if category and parent in VALID_CATEGORIES and category != parent:
        problems.append(
            f"Category {category!r} disagrees with folder {parent!r}"
        )

    impact = fields.get("Impact", "")
    if impact and not any(impact.startswith(prefix) for prefix in VALID_IMPACTS):
        problems.append(f"Impact must start with one of {VALID_IMPACTS}")

    version = fields.get("Version", "")
    if version and not SEMVER.match(version):
        problems.append(f"Version {version!r} is not semver (X.Y.Z)")

    licence = fields.get("License", "")
    if licence and licence != "MIT":
        problems.append(f"License must be 'MIT' (got {licence!r})")

    output_schema = fields.get("Output schema", "")
    if output_schema and "OUTPUT_SCHEMAS.md" not in output_schema:
        problems.append(
            "Output schema field should reference docs/OUTPUT_SCHEMAS.md#<anchor>"
        )

    return problems


def collect_targets(argv: list[str]) -> list[Path]:
    if len(argv) > 1:
        return [Path(p).resolve() for p in argv[1:]]

    targets: list[Path] = []
    for engine_dir in ("mssql", "postgresql", "mysql"):
        engine_path = REPO_ROOT / engine_dir
        if engine_path.exists():
            targets.extend(sorted(engine_path.rglob("*.sql")))
    mongo_path = REPO_ROOT / "mongodb"
    if mongo_path.exists():
        targets.extend(sorted(mongo_path.rglob("*.js")))
    return targets


def main(argv: list[str]) -> int:
    targets = collect_targets(argv)
    if not targets:
        print("no .sql files found — nothing to validate")
        return 0

    failed = 0
    for path in targets:
        rel = path.relative_to(REPO_ROOT) if path.is_relative_to(REPO_ROOT) else path
        problems = validate(path)
        if problems:
            failed += 1
            for p in problems:
                # GitHub Actions annotation format
                print(f"::error file={rel}::{p}")
        else:
            print(f"ok  {rel}")

    if failed:
        print(f"\n{failed} file(s) failed header validation", file=sys.stderr)
        return 1

    print(f"\n{len(targets)} file(s) ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
