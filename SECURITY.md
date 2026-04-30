# Security Policy

## Scope

This is a collection of read-only T-SQL diagnostic queries. The primary security concerns are:

1. **A script claims to be read-only but mutates state.**
2. **A script returns sensitive data unexpectedly** (e.g. plaintext from a column, credentials embedded in plan cache).
3. **A script behaves dangerously on a specific edition** (e.g. takes excessive locks, fills the plan cache, triggers an autogrow storm).

If you find any of the above, please report it privately rather than opening a public issue.

## Reporting

- Open a **GitHub Security Advisory** on this repository: `Security` tab → `Report a vulnerability`.
- Or email the maintainers at the address listed on the DMC organisation page.

We aim to acknowledge reports within 5 business days and ship a fix or mitigation within 30 days for confirmed issues.

## Out of scope

- General SQL Server platform vulnerabilities — those belong with Microsoft.
- Misuse of a script that is correctly labelled (e.g. running a 🔴 Heavy script during peak load).
- Performance characteristics that match the documented impact rating.

## Disclosure

After a fix is released, we will publish a brief advisory in the repository's Security Advisories section, crediting the reporter unless they request otherwise.
