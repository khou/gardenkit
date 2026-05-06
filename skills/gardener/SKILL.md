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
   - `derived-from:` always set when filing — point at the inbox capture filename or external source URL
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

### 5b. Summary + size + edge hygiene

Keep recall cheap by maintaining the per-note `summary:` field, the atomic-size invariant, and the typed edges.

```bash
# Notes missing a summary field
grep -rL "^summary:" ~/garden --include="*.md" --exclude-dir=.git --exclude-dir=inbox

# Notes over the 300-line atomic target
find ~/garden -name "*.md" -not -path "*/.git/*" -not -path "*/inbox/*" \
  -exec sh -c 'lines=$(wc -l < "$1"); [ "$lines" -gt 300 ] && echo "$lines $1"' _ {} \;

# Edges pointing at non-existent files (broken links to fix)
for edge in supersedes depends-on contradicts derived-from part-of; do
  grep -rh "^$edge:" ~/garden --include="*.md" --exclude-dir=.git \
    | sed -E "s/^$edge: *\[?//; s/\].*//; s/, */\n/g" \
    | sort -u | while read path; do
        [ -n "$path" ] && [ ! -f ~/garden/"$path".md ] && echo "broken $edge → $path"
      done
done
```

For each:
- **Missing summary**: read the note, write one sentence (≤140 chars) to `summary:`.
- **Stale summary**: if the body has materially changed since `updated:`, refresh.
- **Oversized note**: split into smaller atomic notes linked from a thin parent. Splits get `part-of: [<parent>]`. Don't force a split if the content genuinely belongs together — but the default is to split.
- **Broken edge**: the target was renamed, merged, or deleted. If renamed/merged, point at the new location. If deleted, remove the edge.
- **Stale edge**: if the body has materially changed and an edge no longer reflects reality, drop it. A wrong edge misleads recall worse than a missing one.

### 6. Update MOCs

For each project/topic MOC, update the "Active threads" or "Recent" section based on notes updated in the last 14 days.

Update `~/garden/00-index.md` "Recent" section with one line per significant change this run.

### 7. Decay

If today is the 1st of the month: consolidate previous month's daily notes into `daily/<YYYY-MM>-summary.md` and delete individual dailies (kept in git history).

### 8. Commit + push

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
