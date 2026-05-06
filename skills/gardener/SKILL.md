---
name: gardener
description: Process the garden vault: file inbox captures into atomic notes, add wiki-links, dedupe, update MOCs, and commit. Run on a schedule (cron or routine), not by hand. Reads ~/garden/meta/gardener-rules.md for heuristics.
---

# gardener

The maintenance agent for `~/garden/`. Reads inbox, files notes, links, dedupes, summarizes. Designed to run unattended on a schedule.

## Phases

Run in order. Stop after any phase if no work to do.

### 1. Pull

```bash
cd ~/garden && git pull --quiet --rebase
```

### 2. Read rules

Read `~/garden/meta/gardener-rules.md` first. These heuristics override defaults below if they conflict. Also read `~/garden/meta/derived-taxonomies.md` and `~/garden/meta/migration-state.md` so the gardener knows what derived MOC types are currently active and what schema migrations are in flight.

### 3. Schema migration / drift cleanup

Bring existing files in line with the current convention before doing new work. The point: when a user pulls a fresh gardenkit version, the next run(s) should clean their vault up to the new standard without hand-editing.

1. Read the authoritative meta files (this is step 2). Compare against `meta/migration-state.md`'s "Last seen meta-file versions". If any have changed, record the diff.
2. Run the auto-migrations described in `meta/gardener-rules.md` section "Schema migration": missing required frontmatter fields, renamed typed edges, folder moves, deprecated frontmatter values, stale derived MOCs.
3. For anything that needs human review (conflicts, content splits, deletions, irreversible changes), leave a `> NOTE: migration: <issue>` blockquote at the top of the affected file rather than guessing.
4. Cap work at ~50 files per run. Track progress in `meta/migration-state.md` in the "In-flight migrations" table; continue on subsequent passes.
5. Append one line to `meta/migration-state.md`'s "Log" heading describing what migrated this pass.

If `meta/migration-state.md` doesn't exist (older vault), create it from the gardenkit template before running this phase.

### 4. Process inbox

For each file in `~/garden/inbox/`:
1. Read the capture.
2. Decide the type: `note`, `decision`, `learning`, `person`, or `project`.
3. Write atomic note(s) to the appropriate folder with proper frontmatter, including a `summary:` field (one sentence, ≤140 chars, plain language, no wiki-links).
4. If the resulting note would exceed ~300 lines, split it into smaller notes. Each split gets `part-of: [<parent-path>]` in its frontmatter.
5. Populate typed edges in frontmatter where the source material is explicit (see `meta/gardener-rules.md` for the full convention):
   - `supersedes:` if the note explicitly replaces an earlier note
   - `depends-on:` if the note explicitly requires another note's outcome
   - `contradicts:` if the note explicitly disagrees with another note
   - `derived-from:` always set when filing; point at the inbox capture filename or external source URL. List multiple sources if synthesized from several.
   - `part-of:` set on splits (see step 4)
   - Don't speculate. Missing edges are fine; wrong edges mislead recall.
6. Add `[[wiki-links]]` in the body to existing projects/people/notes the new note references (default for "related, untyped"). Use `grep -ril` to check what already exists.
7. Delete the inbox file.

If a capture is ambiguous or needs human review, leave a `> NOTE:` blockquote in a draft file in `inbox/_review/` instead of guessing.

### 5. Link maintenance

Find unlinked references: notes that mention a known wiki-target by plain text but don't link it:

```bash
# For each project MOC
for project in ~/garden/projects/*.md; do
  name=$(basename "$project" .md)
  grep -rln "$name" ~/garden --include="*.md" --exclude-dir=.git | \
    xargs grep -L "\[\[$name\]\]"
done
```

Add wiki-links where they're clearly intended.

### 6. Dedupe

Spot near-duplicate notes (similar title or significant body overlap). Merge into the older note. Leave the newer file as a one-line redirect for one cycle, then delete on next run.

### 7. Summary, size, and edge hygiene

Keep recall cheap by maintaining the per-note `summary:` field, the atomic-size invariant, and the typed edges. Three checks, in order:

- **Missing or stale summaries.** Find notes outside `inbox/`, `meta/`, and `00-index.md` that lack a `summary:` field; backfill one sentence (≤140 chars) per note. For notes whose body has materially changed since `updated:`, refresh the summary if the gist no longer matches.
- **Oversized notes.** Find notes outside `inbox/` and `daily/` that exceed ~300 lines; split into smaller atomic notes. Splits get `part-of: [<parent>]`. Don't force a split if the content genuinely belongs together, but the default is to split.
- **Broken or stale live edges.** For each *live* typed-edge field (`supersedes`, `depends-on`, `contradicts`, `part-of`), find values pointing at vault paths that no longer exist. If the target was renamed or merged, point at the new location. If deleted, remove the edge. If the body has materially changed and an edge no longer reflects reality, drop it. A wrong edge misleads recall worse than a missing one. **Skip `derived-from`**: it's provenance, not a live relationship — values may legitimately point at deleted inbox captures (still in git history) or external URLs.

Use `grep`, `find`, and `wc` via the Bash tool however suits the situation. YAML lists may be inline (`[a, b]`) or block-style; handle both.

### 8. Curate derived taxonomies

The gardener owns the derived MOC types in `meta/derived-taxonomies.md`. Each pass:

1. **Scan for new candidates.** Look for classes of entity that recur across atomic notes (companies, vendors, technologies, geographies, conferences, etc.). If 3+ instances each have 2+ supporting notes (or a single instance has 5+), and aggregating would surface non-trivial connections, introduce a new derived type. Append the introduction to `meta/derived-taxonomies.md`.
2. **Regenerate active instances.** For each derived MOC type listed in `meta/derived-taxonomies.md`, regenerate every instance from its `derived-from` sources using the type's render template. Replace, don't merge. The body must open with "**Derived MOC. Do not hand-edit.** Edit the underlying notes; this file is regenerated."
3. **Reconsider merges, splits, retirements.** If two types overlap heavily, propose a merge. If one type has become a junk drawer, propose a split. If a type has fallen below threshold for 2+ consecutive passes, retire it (move files to a date-stamped archive under `meta/`).
4. **Document every taxonomy change** in `meta/derived-taxonomies.md` change log: introduced / merged / split / retired plus reasoning.

The agent has full discretion here. The meta-rule lives in `meta/gardener-rules.md` section "Derived taxonomies"; the audit trail lives in `meta/derived-taxonomies.md`.

### 9. Update hand-curated MOCs

For each project/topic MOC, update the "Active threads" or "Recent" section based on notes updated in the last 14 days.

Update `~/garden/00-index.md` "Recent" section with one line per significant change this run.

### 10. Decay

If today is the 1st of the month: consolidate previous month's daily notes into `daily/<YYYY-MM>-summary.md` and delete individual dailies (kept in git history).

### 11. Commit + push

```bash
cd ~/garden && git add -A && git commit -m "gardener: <date>: <summary of changes>" && git push
```

If no changes, skip commit.

## Safety

- Never delete user-authored notes without leaving a flag for one cycle.
- Always commit gardener changes with `gardener:` prefix so user edits are easy to distinguish.
- If git pull fails (conflict), abort and write a note to `inbox/_gardener-stuck-<date>.md` describing the issue.

## Invocation

Headless via cron / routine:
```bash
claude -p "Run the gardener skill. Today is $(date +%Y-%m-%d)."
```
