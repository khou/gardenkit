---
type: meta
updated: YYYY-MM-DD
---

# Gardener rules

Heuristics the gardener follows when processing the vault. Update as you notice patterns the gardener gets wrong.

## Inbox processing

- Each `inbox/` file is a raw capture. Read, classify, file as one or more atomic notes in the appropriate folder.
- One concept per output note. If a capture covers three things, write three notes.
- Apply frontmatter: `type`, `tags`, `created`, `updated`, `source`, and `summary` (one sentence, ≤140 chars — see below).
- Add `[[wiki-links]]` to any project, person, or note already in the vault that the new note references.
- After successful processing, delete the inbox file (it's now in version control history).

## Atomic-note size

- Target: 50–300 lines per note. If a note exceeds ~300 lines, split it into smaller notes linked from the original (or from a thin MOC if the splits are siblings).
- The size cap is a forcing function for atomicity, not a hard rule — a coherent reference doc that genuinely needs to stay together can stay together. But default to splitting.
- When splitting, preserve the original filename for the canonical "parent" concept and give each split a focused name.

## Summaries

- Every note must have a `summary:` frontmatter field: one sentence, ≤140 chars, plain language, no wiki-links. It answers "what would I learn from reading this?"
- The summary lets recall skim many notes cheaply before reading any body in full. Treat it as the note's title-card for AI consumption.
- When updating a note's body, refresh `summary:` if the gist changed. Stale summaries are worse than missing ones.
- For inbox captures, write the summary as part of filing — it doesn't need to exist on the raw capture itself.

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

Beyond plain wiki-links, the vault uses five typed edge fields in frontmatter. These let recall prune traversal without reading the target note: e.g., a `superseded-by` chain doesn't need following if the query is about current state.

```yaml
supersedes:    [decisions/2024-09-jwt-localstorage]   # this decision replaces these
depends-on:    [decisions/2025-12-cookie-domain]      # this requires these to hold first
contradicts:   [learnings/jwt-localstorage-fine]      # this disagrees with these
derived-from:  [inbox/2026-04-30-security-call]       # this was synthesized from these
part-of:       [notes/auth-architecture]              # this is a subset of these (often after a split)
```

Format: list of vault-relative paths without `.md` extension and without `[[ ]]` brackets — values are YAML strings.

**When to populate:**

- Only when the relationship is **explicit in the source material**. If the capture says "this overrides our earlier decision on X", populate `supersedes`. If it says "we need Y resolved first", populate `depends-on`.
- Never speculate. A missing edge is fine; a wrong edge is worse than none.
- Auto-set `derived-from` whenever a note is filed from an inbox capture or external source — point at the capture filename or source URL.
- Auto-set `part-of` whenever you split an oversized note — the splits point at the parent.

**Reverse edges are not stored.** When recall needs "what supersedes this?", it greps for `supersedes:` containing the file. Keeps the gardener from having to maintain both directions.

**Refresh on update.** When editing a note's body, check whether typed edges still hold. Stale edges mislead recall.

## Dedupe

- If two notes cover the same idea: merge into the older one, keep newer note as a redirect with `> See: [[older-note]]` for one cycle, then delete on next run.
- Flag merges in commit message.

## Daily/weekly summarization

- After 30 days, daily notes from a given month get consolidated into `daily/<YYYY-MM>-summary.md` and individual dailies archived (kept in git history).
- Weekly review goes into `notes/<YYYY>-week-<NN>-review.md`, links from [[00-index]].

## Safety

- Never delete a user-authored note without leaving a `> NOTE: gardener flagged for deletion: <reason>` blockquote and waiting one cycle.
- Always commit gardener changes separately from user edits, with `gardener:` prefix on the message.
