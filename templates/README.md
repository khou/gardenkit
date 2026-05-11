# garden (private vault)

Your LLM-tended second brain. Plain markdown, wiki-links, Obsidian-friendly, agent-maintained.

The framework lives at https://github.com/khou/gardenkit. This repo holds your data.

## Conventions

**Atomic notes.** One concept per file. Target 50–300 lines; split if longer.

**Link, don't nest.** If a note relates to a project, drop a `[[projects/project-name]]` link rather than putting it in a project folder.

**Frontmatter on every note:**

```yaml
---
type: note          # note | decision | person | project | daily | learning
tags: [topic1, topic2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
summary: One sentence, ≤140 chars. What you'd learn from reading this. No wiki-links.
verified: YYYY-MM-DD   # optional: gardener stamps this when the note's claims still hold
# Optional typed edges (gardener populates when relationships are explicit):
supersedes:    [decisions/old-decision]   # this replaces those
depends-on:    [projects/blocking-thing]  # this requires those
contradicts:   [learnings/old-fact]       # this disagrees with those
derived-from:  [inbox/source-capture]     # this was synthesized from those
part-of:       [notes/parent-concept]     # this is a subset of those (often after a split)
---
```

The `summary:` field is what recall reads first when scanning many notes. The body is only loaded when the summary signals it's worth the tokens. Keep summaries fresh; stale is worse than missing.

The `verified:` field is a positive freshness signal: when present, it means the gardener cross-checked the note's claims against the rest of the vault on that date and found them still accurate. Recall can trust a recently-verified note more strongly than an unverified one of the same age. The gardener writes this in the verification-stamping phase (see [[meta/gardener-rules]] section "Verification stamping").

The typed edges let recall skip following links when the relationship type already answers the question: a chain of `supersedes` edges doesn't need following if the query is about current state, a `contradicts` edge surfaces tensions, etc. The gardener populates them only when the source material is explicit, never speculatively. Most notes will have plain `[[wiki-links]]` in the body and zero typed edges, and that's fine.

`derived-from` is special: it's provenance (where the note came from), not a live link. Values often point at inbox captures the gardener deleted after filing; the path remains a valid pointer into git history. The hygiene phase doesn't validate `derived-from` targets; the other four edges (`supersedes`, `depends-on`, `contradicts`, `part-of`) are live and get checked.

## Folders

- `notes/`: atomic notes on any topic
- `projects/`: one MOC per project (a "Map of Content": an index file linking to all notes/decisions on that topic). Backlinks make the MOC a live index.
- `people/`: one file per person worth tracking
- `decisions/`: ADR-style: why we decided X
- `daily/`: one file per day, append-as-you-go
- `learnings/`: TIL-style facts worth keeping
- `inbox/`: raw captures awaiting gardener processing
- `meta/`: vault config, identity files, gardener rules, gardener state (derived-taxonomies and migration-state), and the continuous-refresh source list (refresh-sources)

The gardener may also create **derived-MOC folders** (`companies/`, `vendors/`, etc.) when content crosses the threshold for aggregating. These are agent-curated and regenerated each run; the active type roster lives in [[meta/derived-taxonomies]]. Don't hand-edit anything inside derived-MOC folders: edit the underlying atomic notes and the MOC regenerates.

## Entry point

[[00-index]] is the vault's root. Every session-start loads it.

## Maintenance

The vault is **LLM-tended.** Don't manually file or organize. Capture to `inbox/`; the gardener (scheduled) processes it into atomic notes and links them in.
