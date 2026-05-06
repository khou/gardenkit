---
type: meta
updated: YYYY-MM-DD
---

# Gardener rules

Heuristics the gardener follows when processing the vault. Update as you notice patterns the gardener gets wrong.

## Schema migration

When the gardener convention changes (new frontmatter fields, renamed typed edges, new derived taxonomies, deprecated folders), existing files drift from the current standard. Each gardener pass detects and corrects drift so the vault converges on the latest gardenkit version. The point: a user who pulls a fresh gardenkit version should see the next run(s) clean up to the new standard without hand-editing.

**Authoritative sources** (read at the start of every pass): this file, [[README]], [[meta/derived-taxonomies]], [[meta/migration-state]]. If any have changed since the last pass (compare against [[meta/migration-state]]), record the change and run the migration phase before processing inbox.

**What auto-migrates:**

- Missing required frontmatter fields. Generate from the body and edit in (e.g., `summary:` from the body, `derived-from:` from a "Source:" header line or "from inbox/X" pattern, `created:` / `updated:` from git history).
- Renamed frontmatter fields. If a typed edge gets renamed (e.g., `from` -> `derived-from`), rewrite all instances.
- Folder moves. If a folder is renamed (e.g., `learnings/` -> `lessons/`), move all files and update wiki-links.
- Deprecated frontmatter values. If an enum gets new options or has options removed, map old values to nearest current.
- Stale derived MOCs. If the template for a derived type changes, regenerate every instance.

**What flags for human review** (don't auto-migrate). Write a `> NOTE: migration: <issue>` blockquote at the top of the affected file:

- Conflicting content during a frontmatter rename (old value collides with existing new-name value).
- Long-form content that would need to be split into atomic notes per the current convention.
- Deletion of deprecated content. The user should ratify before content is removed.
- Anything irreversible.

**Pacing.** Cap migration work to ~50 files per run so a single pass commits cleanly. Track progress in [[meta/migration-state]]. Continue on subsequent passes until the count reaches the total. The convergence is intentional, not all-at-once.

**Migration log.** Every step appends a one-line entry to [[meta/migration-state]] under a "Log" heading: what changed, how many files affected, why.

## Derived taxonomies

Some MOCs are not hand-curated. They are regenerated each gardener pass from the underlying atomic notes. The set of derived MOC types is itself emergent: the gardener introduces, merges, splits, and retires them as the vault's content evolves. The current set lives in [[meta/derived-taxonomies]].

### Why this is agent-curated, not hand-coded

Aggregation views (companies, vendor categories, conference talks, geographies) lag whatever taxonomy is current. A hardcoded schema rots; the right taxonomies for the vault next year aren't predictable now. The gardener is in the best position to notice when a class of entity has accumulated enough material to warrant a roll-up, and to retire one that has gone quiet.

### Meta-rule for introducing a new derived type

Each pass, scan for classes of entity that recur across atomic notes. Introduce a derived MOC type when:

- **Threshold:** 3+ instances of the class each have 2+ supporting atomic notes; OR a single instance has 5+ atomic notes that would benefit from a unified roll-up.
- **Cohesion:** the instances are clearly distinguishable from each other.
- **Utility:** aggregating would surface non-trivial connections that grep-across-files cannot easily reveal.

When introducing a new type:

1. Pick a folder name (`<type>s/`).
2. Pick a slug convention.
3. Pick a render template (sections, in order).
4. Write the introduction reason and the template into [[meta/derived-taxonomies]].
5. Generate the first round of MOCs.

### Meta-rule for maintaining derived types

Each pass:

- **Regenerate** every existing derived MOC from its `derived-from` sources. Replace, do not merge with prior content.
- **Reconsider merges:** if two derived MOC types overlap heavily, propose a merge in [[meta/derived-taxonomies]] and migrate.
- **Reconsider splits:** if a derived MOC type has become a junk drawer with internally distinct subgroups, propose a split.
- **Retire** types that have fallen below threshold for 2+ consecutive passes. Move their files to a date-stamped archive folder under `meta/`; do not delete outright.
- **Document every change** in [[meta/derived-taxonomies]] with one line: introduced / merged / split / retired plus reasoning.

The agent has full discretion. If the gardener decides "geographies" is worth a folder this pass and "vendor categories" should retire, that judgment overrides anything older in this rules file. Update this file (and `derived-taxonomies.md`) to reflect the new state.

### Frontmatter for derived MOCs

Every derived MOC declares itself:

```yaml
---
type: <slug>          # e.g. company, vendor, technology
slug: <instance>
regenerated: <YYYY-MM-DD>
derived-from: [<source-note>, <source-note>, ...]
summary: <one-sentence>
---
```

The body opens with: "**Derived MOC. Do not hand-edit.** Edit the underlying notes; this file is regenerated."

## Inbox processing

- Each `inbox/` file is a raw capture. Read, classify, file as one or more atomic notes in the appropriate folder.
- One concept per output note. If a capture covers three things, write three notes.
- Apply frontmatter: `type`, `tags`, `created`, `updated`, and `summary` (one sentence, ≤140 chars; see "Summaries" below). Provenance goes in the `derived-from:` typed edge, not a `source:` field.
- Add `[[wiki-links]]` to any project, person, or note already in the vault that the new note references.
- After successful processing, delete the inbox file (it's now in version control history).

## Atomic-note size

- Target: 50–300 lines per note. If a note exceeds ~300 lines, split it into smaller notes linked from the original (or from a thin MOC if the splits are siblings).
- The size cap is a forcing function for atomicity, not a hard rule. A coherent reference doc that genuinely needs to stay together can stay together, but default to splitting.
- When splitting, preserve the original filename for the canonical "parent" concept and give each split a focused name.

## Summaries

- Every note must have a `summary:` frontmatter field: one sentence, ≤140 chars, plain language, no wiki-links. It answers "what would I learn from reading this?"
- The summary lets recall skim many notes cheaply before reading any body in full. Treat it as the note's title-card for AI consumption.
- When updating a note's body, refresh `summary:` if the gist changed. Stale summaries are worse than missing ones.
- For inbox captures, write the summary as part of filing; it doesn't need to exist on the raw capture itself.

## What to keep

- Decisions made (with reasoning)
- Things learned (TIL-style facts, especially non-obvious ones)
- Open questions worth tracking
- Factual claims about projects/people/tools (state, status, opinions held, links)
- Useful references (URLs with one-line description of what's there)

## What to drop

- Conversational fluff
- Restatements of things already in the vault (unless the restatement adds nuance)
- Speculation without commitment

## Linking

- When a note mentions a project name, person, or known tag, ensure the `[[wiki-link]]` exists in the body. This is the default for "related, untyped" relationships.
- Never create a new MOC unless the topic has 3+ supporting notes.
- Backlinks accumulate naturally: don't manually maintain them.

## Typed edges

Beyond plain wiki-links, the vault uses five typed edge fields in frontmatter. These let recall skip following links without reading the target note: e.g., when answering a current-state query, recall can stop following a chain of `supersedes` edges as soon as it has the latest decision.

```yaml
supersedes:    [decisions/2024-09-jwt-localstorage]   # this decision replaces these
depends-on:    [decisions/2025-12-cookie-domain]      # this requires these to hold first
contradicts:   [learnings/jwt-localstorage-fine]      # this disagrees with these
derived-from:  [inbox/2026-04-30-security-call]       # this was synthesized from these
part-of:       [notes/auth-architecture]              # this is a subset of these (often after a split)
```

Format: list of vault-relative paths without `.md` extension and without `[[ ]]` brackets. Values are YAML strings.

**Two flavors:**

- **Live edges** (`supersedes`, `depends-on`, `contradicts`, `part-of`): describe relationships between live notes. Targets must exist in the vault. The hygiene phase validates them and flags broken or stale ones.
- **Provenance** (`derived-from`): records where a note came from. Often points at an inbox capture (which the gardener deletes after filing; the file lives on in git history), an external URL, or a transcript filename. **Not validated by hygiene** — broken-looking targets are usually correct provenance into git history.

**When to populate:**

- Only when the relationship is **explicit in the source material**. If the capture says "this overrides our earlier decision on X", populate `supersedes`. If it says "we need Y resolved first", populate `depends-on`.
- Never speculate. A missing edge is fine; a wrong edge is worse than none.
- Auto-set `derived-from` whenever a note is filed from an inbox capture or external source: point at the capture filename or source URL. List multiple sources if the note synthesizes from several. Don't worry that the inbox file gets deleted right after; the path is provenance into git history, not a live link.
- Auto-set `part-of` whenever you split an oversized note: the splits point at the parent.

**Reverse edges are not stored.** When recall needs "what supersedes this?", it greps for `supersedes:` containing the file. Keeps the gardener from having to maintain both directions.

**Refresh on update.** When editing a note's body, check whether live edges still hold. Stale live edges mislead recall. Provenance doesn't change.

## Dedupe

- If two notes cover the same idea: merge into the older one, keep newer note as a redirect with `> See: [[older-note]]` for one cycle, then delete on next run.
- Flag merges in commit message.

## Daily/weekly summarization

- After 30 days, daily notes from a given month get consolidated into `daily/<YYYY-MM>-summary.md` and individual dailies archived (kept in git history).
- Weekly review goes into `notes/<YYYY>-week-<NN>-review.md`, links from [[00-index]].

## Safety

- Never delete a user-authored note without leaving a `> NOTE: gardener flagged for deletion: <reason>` blockquote and waiting one cycle.
- Always commit gardener changes separately from user edits, with `gardener:` prefix on the message.
