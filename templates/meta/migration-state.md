---
type: meta
updated: YYYY-MM-DD
---

# Migration state

> **Gardener-owned. Do not hand-edit.** The gardener writes here at the end of every pass.

State tracker for in-flight schema migrations. The gardener uses it at the start of every pass to know what convention versions have been seen, then appends here at the end with what ran.

## Last seen meta-file versions

(Empty. The gardener writes a row per authoritative file with the last-seen content hash or rev and the date it was checked.)

## In-flight migrations

(Empty. The gardener writes a row per migration: name, total files, done count, pending count, notes. Removes rows when `done == total`.)

## Log

(Empty. The gardener appends one line per pass: what migrated, how many files affected.)
