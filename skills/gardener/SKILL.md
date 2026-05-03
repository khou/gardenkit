---
name: gardener
description: Process the garden vault — file inbox captures into atomic notes, add wiki-links, dedupe, update MOCs, and commit. Run on a schedule (cron or routine), not by hand. Reads ~/garden/meta/gardener-rules.md for heuristics.
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
3. Write atomic note(s) to the appropriate folder with proper frontmatter.
4. Add `[[wiki-links]]` to existing projects/people/notes the new note references. Use `grep -ril` to check what already exists.
5. Delete the inbox file.

If a capture is ambiguous or needs human review, leave a `> NOTE:` blockquote in a draft file in `inbox/_review/` instead of guessing.

### 4. Link maintenance

Find unlinked references — notes that mention a known wiki-target by plain text but don't link it:

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

### 6. Update MOCs

For each project/topic MOC, update the "Active threads" or "Recent" section based on notes updated in the last 14 days.

Update `~/garden/00-index.md` "Recent" section with one line per significant change this run.

### 7. Decay

If today is the 1st of the month: consolidate previous month's daily notes into `daily/<YYYY-MM>-summary.md` and delete individual dailies (kept in git history).

### 8. Commit + push

```bash
cd ~/garden && git add -A && git commit -m "gardener: <date> — <summary of changes>" && git push
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
