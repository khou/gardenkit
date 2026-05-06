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

Read `~/garden/meta/gardener-rules.md` first. These heuristics override defaults below if they conflict.

### 3. Process inbox

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

### 4. Link maintenance

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

### 5. Dedupe

Spot near-duplicate notes (similar title or significant body overlap). Merge into the older note. Leave the newer file as a one-line redirect for one cycle, then delete on next run.

### 6. Summary, size, and edge hygiene

Keep recall cheap by maintaining the per-note `summary:` field, the atomic-size invariant, and the typed edges. Three checks, in order:

- **Missing or stale summaries.** Find notes outside `inbox/`, `meta/`, and `00-index.md` that lack a `summary:` field; backfill one sentence (≤140 chars) per note. For notes whose body has materially changed since `updated:`, refresh the summary if the gist no longer matches.
- **Oversized notes.** Find notes outside `inbox/` and `daily/` that exceed ~300 lines; split into smaller atomic notes. Splits get `part-of: [<parent>]`. Don't force a split if the content genuinely belongs together, but the default is to split.
- **Broken or stale typed edges.** For each typed-edge field (`supersedes`, `depends-on`, `contradicts`, `derived-from`, `part-of`), find values pointing at vault paths that no longer exist (skip URL values in `derived-from`, which are valid). If the target was renamed or merged, point at the new location. If deleted, remove the edge. If the body has materially changed and an edge no longer reflects reality, drop it. A wrong edge misleads recall worse than a missing one.

Use `grep`, `find`, and `wc` via the Bash tool however suits the situation. YAML lists may be inline (`[a, b]`) or block-style; handle both.

### 7. Update MOCs

For each project/topic MOC, update the "Active threads" or "Recent" section based on notes updated in the last 14 days.

Update `~/garden/00-index.md` "Recent" section with one line per significant change this run.

### 8. Decay

If today is the 1st of the month: consolidate previous month's daily notes into `daily/<YYYY-MM>-summary.md` and delete individual dailies (kept in git history).

### 9. Commit + push

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
