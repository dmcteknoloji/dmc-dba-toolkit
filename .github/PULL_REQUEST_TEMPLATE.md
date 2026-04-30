# Pull Request

## What does this change?

<!-- One or two sentences. -->

## Type

- [ ] New diagnostic script
- [ ] Bug fix in existing script
- [ ] Compatibility update (new engine version supported)
- [ ] Documentation
- [ ] Tooling / CI

## Checklist

- [ ] New/changed `.sql` files all carry the standard header
- [ ] `python scripts/validate_headers.py` passes locally
- [ ] `sqlfluff lint` has no errors on changed files
- [ ] Output schema added/updated in `docs/OUTPUT_SCHEMAS.md`
- [ ] Compatibility matrix updated (`docs/COMPATIBILITY_MATRIX.md` and README)
- [ ] Tested on at least one engine version listed in the header
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Tested on

<!-- e.g. SQL Server 2022 CU13 on Windows; Azure SQL DB (S2). -->

## Notes for reviewers

<!-- Anything non-obvious: trade-offs, alternatives considered, edge cases. -->
