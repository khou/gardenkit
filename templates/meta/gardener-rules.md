---
type: meta
updated: YYYY-MM-DD
---

# Gardener rules

Heuristics the gardener follows when processing the vault. Update as you notice patterns the gardener gets wrong.

## What the gardener is for: Verify, Organize, Enrich

The gardener is the vault's **out-of-band maintenance loop**. It is the personal-vault equivalent of what Anthropic ships as "dreaming" for agent memory: a batch process that runs separately from the user's hot path, spends compute to keep memory accurate and well-organized, and amortizes that cost across every future recall.

Three explicit jobs every pass should keep in mind:

1. **Verify.** Cross-check existing notes against the rest of the vault and against newer captures arriving in `inbox/`. When a note's claims still hold, stamp it as verified so recall can trust it. When the latest evidence contradicts, set `supersedes:` / `contradicts:` or flag for human review. See "Consistency check" and "Verification stamping" below.
2. **Organize.** Dedupe, link, regenerate derived MOCs, sweep stale entries. Keep structure converging as content accumulates. See "Dedupe", "Derived taxonomies", and "Stale-entry sweep" below.
3. **Enrich.** Surface cross-note patterns no single capture could see. Promote recurring themes to synthesis notes. Extend the derived-MOC mechanism beyond entity types to thematic patterns when threshold is met. See "Thematic synthesis" below.

The gardener may spend a non-trivial token budget on this work each pass. The cost is paid once and amortized across every recall. Spend it.

The substrate for verification, in a personal vault, is the rest of the vault plus the steady stream of new captures landing in `inbox/`. (The same principle applied to production agent memory uses a different substrate: service-rename events, span signatures, deploy events, commit SHAs. Substrate differs; loop is the same.)

## Schema migration

When the gardener convention changes (new frontmatter fields, renamed typed edges, deprecated folders), existing files drift. Each gardener pass detects and corrects drift so a freshly-pulled gardenkit version converges the vault over the next runs without hand-editing.

Authoritative sources, read at the start of every pass: this file, [[README]], [[meta/derived-taxonomies]]. The gardener also reads the gardenkit template copies (resolvable from `~/.claude/skills/gardener` symlink) to detect rules-file drift the user's `cp -n` couldn't pick up.

**Auto-migrates:** missing required frontmatter fields (generate from body, "Source:" headers, or git history); renamed frontmatter fields (rewrite all instances); folder moves (move files, update wiki-links); deprecated frontmatter values (map to nearest current); stale derived MOCs whose template changed (regenerate).

**Flags for human review** (write a `> NOTE: migration: <issue>` blockquote at top): conflicting content during a frontmatter rename, content that would need splitting into atomic notes, deletion of deprecated content, anything irreversible.

**Pacing.** Cap migration work to ~50 files per run. Track progress in [[meta/migration-state]] and append one log line per pass: what changed, how many files affected.

## Derived taxonomies

Some MOCs are not hand-curated. They are regenerated each gardener pass from the underlying atomic notes. The set of derived MOC types is itself emergent: the gardener introduces, merges, splits, and retires them as the vault evolves. Current set, active templates, and change log live in [[meta/derived-taxonomies]].

**Threshold for introducing a new type:** 3+ instances of the class each with 2+ supporting atomic notes, OR a single instance with 5+ supporting notes. Below threshold, log the candidate in [[meta/derived-taxonomies]] and re-evaluate next pass.

**When introducing a type:** pick a folder name (`<type>s/`), pick a render template, write both into [[meta/derived-taxonomies]] with the reason, generate the first round of MOCs.

**Maintenance each pass:** regenerate every active instance from its `derived-from:` sources (replace, don't merge). Propose merges when two types overlap heavily, splits when a type becomes a junk drawer, retirement when a type falls below threshold for 2+ passes. Document the decision in [[meta/derived-taxonomies]].

**Frontmatter for a derived MOC:**

```yaml
---
type: <type>            # e.g. company, vendor, technology -- agent-introduced, extends the atomic-note type enum
tags: [...]
created: <YYYY-MM-DD>   # when this instance first materialized
updated: <YYYY-MM-DD>   # last regeneration
derived-from: [<live-source-note>, ...]   # live, not provenance: see Typed edges below
summary: <one-sentence>
---
```

Body opens with: `**Derived MOC. Do not hand-edit.** Edit the underlying notes; this file is regenerated.`

The agent has full discretion here. If the gardener decides a class deserves a folder, or a stale type should retire, that judgment overrides anything older in this file: update [[meta/derived-taxonomies]] to reflect the new state.

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
- **Provenance** (`derived-from`): on atomic notes, records where the note came from. Often points at an inbox capture (which the gardener deletes after filing; the file lives on in git history), an external URL, or a transcript filename. **Not validated by hygiene**: broken-looking targets are usually correct provenance into git history. **Exception**: on a derived MOC (see "Derived taxonomies" above), `derived-from` enumerates the live source notes used in regeneration; targets must exist for the regenerate phase to work, so hygiene treats them as live edges when `type` is a derived-MOC type.

**When to populate:**

- During inbox processing, only when the relationship is **explicit in the source material**. If the capture says "this overrides our earlier decision on X", populate `supersedes`. If it says "we need Y resolved first", populate `depends-on`.
- The consistency-check phase is an exception: it may set `supersedes:` and `contradicts:` based on cross-note inference, with the confidence thresholds in that section.
- Never speculate. A missing edge is fine; a wrong edge is worse than none.
- Auto-set `derived-from` whenever a note is filed from an inbox capture or external source: point at the capture filename or source URL. List multiple sources if the note synthesizes from several. Don't worry that the inbox file gets deleted right after; the path is provenance into git history, not a live link.
- Auto-set `part-of` whenever you split an oversized note: the splits point at the parent.

**Reverse edges are not stored.** When recall needs "what supersedes this?", it greps for `supersedes:` containing the file. Keeps the gardener from having to maintain both directions.

**Refresh on update.** When editing a note's body, check whether live edges still hold. Stale live edges mislead recall. Provenance doesn't change.

## Consistency check

The brain drifts. New notes silently invalidate older ones; a person's role moves on but their file still says the old thing; two decisions cover the same area without referencing each other. The dedupe and edge-hygiene phases catch structural problems (duplicates, broken targets) but not semantic ones (contradictions, stale facts). The consistency-check phase covers that gap.

This is the one phase where the gardener may set typed edges based on **cross-note inference** rather than the "explicit in source material" rule that governs inbox processing. The bar is higher: be sure before setting `supersedes:` or rewriting a hub's status; be moderately sure before setting `contradicts:` (recall surfaces both sides anyway); flag rather than guess.

**Scope each pass (bounded so token cost stays predictable):**

- **This-run scope, always.** Every note created or modified by the gardener in earlier phases. For each, find related notes via wiki-links in the body, shared tags, shared `[[projects/...]]` or `[[people/...]]` references, and existing typed-edge targets. Compare summaries first; only read bodies when summaries diverge or one of them lacks the substance to judge.
- **Rolling sweep, capped ~10 notes/pass.** Sample from project MOCs, people files, and decisions whose `updated:` is oldest. These are the notes most likely to drift unnoticed because nothing recently has touched them. Skip the rolling sweep if the this-run scope is already large (>~20 notes); let the next pass pick it up.

**Outcomes when a conflict surfaces:**

- **Clear replacement** — newer note factually invalidates older. Set `supersedes:` on the newer pointing at the older. High confidence required.
- **Genuine disagreement** — both still hold and readers should see both sides. Set `contradicts:` on the newer pointing at the older. Moderate confidence is enough.
- **Hub status drift** — a person's role / a project's state has clearly moved, corroborated by 2+ recent notes. Update the hub file's frontmatter and body in place; commit message cites the corroborating notes.
- **Ambiguous** — leave a `> NOTE: consistency: <issue>` blockquote at the top of the newer note. Don't guess. The flag persists for one cycle so a human can resolve it; the next pass treats it as a real edge if confirmed.

**Logging.** Append one line per pass to `meta/migration-state.md`'s Log section, prefixed `consistency:` so it's distinguishable from migration entries.

## Dedupe

- If two notes cover the same idea: merge into the older one, keep newer note as a redirect with `> See: [[older-note]]` for one cycle, then delete on next run.
- Flag merges in commit message.

## Verification stamping (positive maintenance)

Companion to the consistency check, which finds *contradictions*. When the gardener cross-checks a note's claims against the rest of the vault and the latest source material and finds it **still accurate**, leave a positive freshness signal so recall can trust the note without re-deriving.

- Use the same sample as the consistency-check phase (this-run scope plus the rolling cap). For each note where claims hold and no contradiction surfaced, set or refresh a `verified: YYYY-MM-DD` frontmatter field with today's date.
- Optionally append a one-line `> VERIFIED <date>: corroborated by [[a]], [[b]]; no contradicting evidence in last 14 days.` blockquote at the top of the body for high-recall hubs.
- Cap to ~10 notes per pass. Prioritize notes with oldest `verified:` and notes that are heavily linked-from (high recall value).
- Don't stamp ambiguous notes. Verification is positive; absence of contradiction is not the same as positive corroboration. When in doubt, leave it.

A note carrying `verified: 2026-05-10` is a stronger recall signal than a note with no stamp at all, because it tells recall the gardener has actually looked at this recently. The pair (positive `verified:`, negative `supersedes:` / `contradicts:`) is the vault analog of what Anthropic's dreaming produces.

## Thematic synthesis (Enrich)

Beyond entity-shaped derived MOCs, surface **thematic patterns** that recur across atomic notes but are not naturally an entity. Examples:

- Same objection appearing in 3+ customer-feedback contexts → propose a recurring-objection synthesis note.
- Same positive frame validated in 3+ conversations → propose a validated-thesis synthesis note.
- Same failure mode or strategy across 3+ debug or build sessions → propose a learning synthesis note.
- A vocabulary shift (new term replacing an old one in 3+ recent notes) → propose a glossary update.

**Threshold**: 3+ atomic notes touching the theme in the last 30 days, where the theme is not already covered by a hub note, MOC, or existing synthesis.

**Output**: a proposed synthesis note in `notes/`, opened with a `> NOTE: gardener proposed synthesis: <theme>; sources [[a]], [[b]], [[c]]. Ratify by editing this blockquote.` blockquote. The user ratifies by removing the NOTE block on a subsequent pass.

**Cap**: at most 2 new synthesis proposals per pass. Quality over quantity.

Run thematic synthesis after derived-MOC regeneration so the regenerated MOCs are available as inputs.

## Stale-entry sweep

Each pass, scan for content that has been factually obsoleted but is still surfacing in active hubs and MOCs:

- **Superseded decisions** older than 60 days with no recent references → propose archival via `> NOTE: gardener flagged for archival: superseded N days ago, no references in last M days.`
- **Resolved / dropped questions** older than 14 days → archive to `questions/_archive/<YYYY>/` (kept in git history).
- **Active decisions** not referenced anywhere in the last 90 days → flag with `> NOTE: gardener: decision quiet for 90+ days, still active? <date>` for the user to confirm or reverse.
- **Stale `verified:` stamps** older than 90 days → eligible for re-verification on next pass; prioritize them in the verification-stamping sample.

Symmetric with verification stamping: stamps amplify what recall should trust; the stale sweep quiets what recall should mistrust.

## Daily/weekly summarization

- After 30 days, daily notes from a given month get consolidated into `daily/<YYYY-MM>-summary.md` and individual dailies archived (kept in git history).
- Weekly review goes into `notes/<YYYY>-week-<NN>-review.md`, links from [[00-index]].

## Safety

- Never delete a user-authored note without leaving a `> NOTE: gardener flagged for deletion: <reason>` blockquote and waiting one cycle.
- Always commit gardener changes separately from user edits, with `gardener:` prefix on the message.
