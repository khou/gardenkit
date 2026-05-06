---
type: meta
updated: YYYY-MM-DD
summary: The gardener's own state tracker for in-flight schema migrations. The agent reads this at the start of every pass to know what convention versions have been seen and what backfill work is in progress.
---

# Migration state

Auto-managed by the gardener. Do not hand-edit unless you know what you're doing; the gardener writes here.

## Last seen meta-file versions

The gardener compares these against the current state of the meta files at the start of every pass. Differences trigger the schema migration phase.

| File | Last seen rev | Last checked |
|---|---|---|
| meta/gardener-rules.md | (initial install) | YYYY-MM-DD |
| meta/derived-taxonomies.md | (initial install) | YYYY-MM-DD |
| README.md | (initial install) | YYYY-MM-DD |

## In-flight migrations

(Empty. The gardener adds rows here when a schema change requires backfilling existing files. Format: migration name, total files, done count, pending count, notes. Remove rows when `done == total`.)

## Log

(Empty. The gardener appends one line per pass: what changed, how many files affected, why.)

## Conventions for this file

- The gardener owns this file. It writes here at the end of every pass.
- New rows in the in-flight migrations table when a new schema change is detected.
- Done count incremented as files are migrated.
- Remove rows when the migration is complete.
- Append a one-line log entry per pass.
