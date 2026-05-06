---
type: meta
updated: YYYY-MM-DD
summary: Change log of auto-derived MOC types in this vault. The gardener owns this file: each pass it can introduce, merge, split, or retire derived types based on what the vault currently holds.
---

# Derived taxonomies

Audit trail of the gardener's taxonomy decisions. The agent has full discretion to introduce, merge, split, or retire derived MOC types each pass; this file records what it has decided and what active templates each type uses.

See [[meta/gardener-rules]] section "Derived taxonomies" for the meta-rule.

## Currently active

(None yet. The gardener will introduce a derived type the first time it spots a class of entity that crosses the threshold: 3+ instances of the class with 2+ supporting atomic notes each, OR a single instance with 5+ atomic notes that would benefit from a unified roll-up.)

When a type is introduced, the gardener appends a section here with:

- **Introduced:** date.
- **Reason:** why this class deserves a derived MOC.
- **Threshold met:** how many instances qualified.
- **Slug convention:** how filenames are formed.
- **Render template:** the sections, in order.
- **Source order for derivation:** which notes the gardener walks, in what order.
- **Active instances:** the files currently materialized.

## Future candidates (under threshold)

(The gardener notes classes it has spotted but that have not yet crossed the threshold. Re-evaluate each pass.)

## Retired

(Empty.)

## Change log

(Empty. The gardener appends one line per pass when it introduces, merges, splits, or retires a taxonomy type.)
