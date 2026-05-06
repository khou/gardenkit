---
name: garden-bootstrap
description: Bootstrap the garden vault from connected data sources. Surveys what's available, proposes a plan tailored to the user's context, asks for confirmation, then executes. Suggests additional data sources to connect for richer coverage. Use after the initial install and after `meta/user.md` is filled in. Two modes, `init` (first-time pull) and `refresh` (top-up since last run).
---

# garden-bootstrap

Pulls data from the user's connected systems (Gmail, Google Drive, Slack, others) and writes a first cut of the vault: people files, project MOCs, decisions, reference notes, relevant transcripts. The skill is **conversational, not prescriptive**: it surveys what's available, derives a candidate plan based on the user's context, presents it for confirmation, and only executes what the user signs off on.

The garden becomes useful in proportion to how much real context lives in it. This skill makes the initial population a guided agent invocation rather than a manual chore, while leaving the user in control of what gets pulled and how.

## When to run

- **`init`**: right after `install.sh`, after `meta/user.md` is filled in (so the agent has context for who matters and what to look for).
- **`refresh`**: weekly or monthly. Top up new data since the last run. Idempotent.

## Mode: init

### Step 1: Survey and derive

- Read `~/garden/meta/user.md` for the user's role, who they work with, recurring topics, and the tools they live in. This is the steering context for everything else.
- Inventory which MCPs are connected in the current session (Gmail, Drive, Slack are common; others may be present). Don't list MCPs you don't see.
- Skim each available source lightly to derive what's there. For example: which Slack channels are active, what's in the primary project Drive folder, who the dominant senders / recipients in Gmail are. Keep the survey shallow; the goal is to inform a proposal, not to do the bootstrap yet.

### Step 2: Propose a plan

Synthesize a short plan (typically 5 to 10 bullets) tailored to what was surveyed and what `user.md` says matters. Each bullet should name the source, what to pull, and what gets written to the vault. Aim for a plan that takes roughly 20 minutes to execute.

Generic shape:

- "Pull recent messages in `#<channel>` from Slack, summarize state-of-the-company into `inbox/`."
- "Search Drive for the `<project>` folder, inventory `Fundraising/` and `MeetingTranscripts/`, write per-person profiles for everyone met."
- "Search Gmail for follow-up threads with named contacts from `meta/user.md`, capture verbatim quotes for downstream pitch / FAQ notes."
- "Read the investor list / customer research spreadsheet (if found), write atomic notes for the most-engaged contacts."

Do not invent sources that aren't connected. If something common is missing (e.g., user lives in Linear per `user.md` but no Linear MCP is connected), flag it as a gap rather than skipping silently.

### Step 3: Present and confirm

Show the plan to the user. Ask which bullets to keep, which to drop, what to add. Common tweaks:

- "Skip Drive, my context lives in Notion."
- "Don't profile X, they're not relevant anymore."
- "Also pull our `#ext-<customer>` channel."
- "Focus on the last 30 days, not all-time."

Wait for confirmation before executing. The whole point of the proposal step is to avoid scraping everything by default.

### Step 4: Execute

Work through the agreed plan one bullet at a time. Brief status updates between bullets. If a step turns out larger than expected (a transcript too big for direct read, a Slack channel with thousands of messages, an email thread with many sub-threads), pause and ask whether to delegate to a subagent or narrow scope.

Apply the existing vault conventions:

- Atomic notes per the [[README]] rules. One concept per file, target 50–300 lines.
- Frontmatter on every note, including a one-sentence `summary:` field (≤140 chars). Wiki-links in the body for related people / notes / projects.
- Typed edges (`supersedes`, `depends-on`, `contradicts`, `derived-from`, `part-of`) when the source material is explicit — never speculatively. Always set `derived-from:` pointing at the source (Drive doc URL, Slack permalink, transcript filename) so provenance is recoverable.
- People files in `people/`, MOCs in `projects/`, atomic notes in `notes/`, decisions in `decisions/`, raw captures in `inbox/`.
- The gardener will dedupe, refresh summaries, and tighten edges on its next run.

### Step 5: Suggest additional sources

After executing, look at gaps: what could enrich the vault that wasn't pulled this round? Surface 2 to 4 specific suggestions tailored to what `user.md` says under "Tools Kevin lives in" or equivalent. **Don't dump the full menu**; recommend only the most likely.

Categories to consider when relevant:

- Meeting transcript services (Granola, Fireflies, Otter, Zoom AI, Read.ai)
- CRM / sales pipeline (HubSpot, Salesforce, Close, Attio, Pipedrive)
- Issue tracker / project management (Linear, Jira, Asana, Notion, ClickUp)
- Code (GitHub PRs, issues, releases, commit messages)
- Customer support (Intercom, Zendesk, Freshdesk, Plain)
- Calendar (Google, Outlook)
- Documents beyond Drive (Notion, Confluence, Quip, Coda)
- Chat beyond Slack (Discord, Teams, Telegram)
- Voice notes / dictation (Apple Voice Memos plus Whisper, auto-transcribers)
- Read-later / web research (Pocket, Instapaper, Readwise, browser exports)
- Personal note apps (other Obsidian vaults, Apple Notes, Bear)
- Email beyond primary (Outlook, IMAP for personal)

Ask which (if any) the user wants to connect before the next refresh.

### Step 6: Commit

```
git -C ~/garden add -A
git -C ~/garden commit -m "bootstrap: init from <sources> on <date>"
```

## Mode: refresh

Idempotent top-up. Run weekly or monthly.

1. Read `~/garden/00-index.md` to find when the last bootstrap or gardener run was.
2. Survey the same sources used in `init`, filtered to dates after the last run.
3. Propose a focused refresh plan (typically 2 to 5 bullets). Skip steps where the diff is empty.
4. Confirm with the user. Execute. Update existing files where signals changed; create new files for new people, projects, decisions.
5. Append a `Recent (auto-updated)` line to `00-index.md` summarizing the round.
6. Commit with `bootstrap: refresh, <one-line summary>`.

## What to watch for

- **Attribution mistakes.** When synthesizing from transcripts, double-check who said what before quoting in someone's profile. If unsure, write `> NOTE: speaker attribution unconfirmed` rather than guessing.
- **Sensitive interpersonal patterns.** Working dynamics between cofounders, performance issues, etc. should be captured carefully if at all. Flag for the user before writing rather than assuming consent.
- **Overcollection.** Goal is a useful index, not a complete archive. Skip routine ops (calendar invites, billing emails, marketing newsletters) unless the user asks for them.
- **Stale data.** If a source has not produced new data since the last run, do not invent updates.

## Privacy and safety

- The vault is **private**. Never push pulled content to a public repo. Sanity-check `git remote -v` before commit.
- Don't quote others' Slack DMs without explicit user OK. Quote the user's own messages or messages from public / team channels by default.
- Strip secrets (API keys, tokens, passwords) from any text before writing.
- If a transcript or doc is marked confidential by metadata or content, flag and ask before mining.

## Don't

- Don't skip the proposal step. The user must confirm before any pull begins.
- Don't run `init` repeatedly. Switch to `refresh` after the first pass.
- Don't try to mine sources that aren't connected. Tell the user what's missing and suggest connecting it.
- Don't write speculative future-state into people files. Capture observed history; let the user direct strategy.
