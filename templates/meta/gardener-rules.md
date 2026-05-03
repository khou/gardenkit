---
type: meta
updated: YYYY-MM-DD
---

# Gardener rules

Heuristics the gardener follows when processing the vault. Update as you notice patterns the gardener gets wrong.

## Inbox processing

- Each `inbox/` file is a raw capture. Read, classify, file as one or more atomic notes in the appropriate folder.
- One concept per output note. If a capture covers three things, write three notes.
- Apply frontmatter (type, tags, created, updated, source).
- Add `[[wiki-links]]` to any project, person, or note already in the vault that the new note references.
- After successful processing, delete the inbox file (it's now in version control history).

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

- When a note mentions a project name, person, or known tag, ensure the wiki-link exists.
- Never create a new MOC unless the topic has 3+ supporting notes.
- Backlinks accumulate naturally: don't manually maintain them.

## Dedupe

- If two notes cover the same idea: merge into the older one, keep newer note as a redirect with `> See: [[older-note]]` for one cycle, then delete on next run.
- Flag merges in commit message.

## Daily/weekly summarization

- After 30 days, daily notes from a given month get consolidated into `daily/<YYYY-MM>-summary.md` and individual dailies archived (kept in git history).
- Weekly review goes into `notes/<YYYY>-week-<NN>-review.md`, links from [[00-index]].

## Safety

- Never delete a user-authored note without leaving a `> NOTE: gardener flagged for deletion: <reason>` blockquote and waiting one cycle.
- Always commit gardener changes separately from user edits, with `gardener:` prefix on the message.
