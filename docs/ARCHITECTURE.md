# Architecture

The thinking behind gardenkit.

## Goals

- **Single vault, all topics.** No per-topic directory structure to switch between.
- **LLM-maintained.** You capture; the agent organizes.
- **Obsidian-visualizable.** Plain markdown + wiki-links → graph view, backlinks, tags all work.
- **Portable across environments.** Works in Claude Code (local), Cowork (cloud), Obsidian (desktop/mobile), with the vault in git.

## The vault

Light folder structure, navigation by wiki-links:

```
~/garden/
├── 00-index.md             ← entry point loaded at session start
├── notes/                  ← atomic notes, all topics
├── projects/               ← one MOC per project (links accumulate)
├── people/                 ← one file per person worth tracking
├── decisions/              ← ADR-style: why we decided X
├── daily/                  ← one per day
├── learnings/              ← TIL-style facts
├── inbox/                  ← raw captures awaiting gardener
└── meta/
    ├── user.md             ← who you are, preferences
    ├── soul.md             ← agent persona
    └── gardener-rules.md   ← maintenance heuristics
```

Folders are *templates*, not topics. A note about a project goes in `notes/` and links to `[[projects/<name>]]`. Backlinks make the project page a live index.

## Atomic notes

Every note: one concept, frontmatter, body, links.

```yaml
---
type: note
tags: [topic1, topic2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

Two rules carry the system:
1. **One concept per file.**
2. **Link, don't nest.**

## The three loops

### Recall (session start)
A `SessionStart` hook pulls latest from git and prints `00-index.md` + `meta/user.md` + `meta/soul.md` to stdout. Claude Code injects this as additional context for the new session. The agent then follows wiki-links on demand for deeper context.

### Capture (during/after session)
The `garden-capture` skill writes a raw markdown file into `inbox/`. This can be triggered by:
- The user explicitly: "capture this"
- The `SessionEnd` hook — when a session ends, extracts noteworthy items from the transcript into inbox files
- The `PreCompact` hook — when context is about to be compacted (auto or manual `/compact`), captures items from the soon-to-be-truncated portion before they're lost. Honors `custom_instructions` from manual compactions as a hint to the extractor.

Both auto-capture hooks share `scripts/extract-to-inbox.sh`, parameterized by source label. The script reads the transcript, pipes user+assistant text through `claude -p` with a focused extraction prompt, writes one inbox file per noteworthy item, and runs the heavy work in the background so the hook returns immediately.

Tunable via env vars:
- `GARDEN_CAPTURE_MIN_WORDS` (default 200) — skip extraction if transcript is shorter
- `GARDEN_CAPTURE_MAX_ITEMS` (default 5) — cap captures per run

Inbox files stay raw. The gardener decides what to keep and where to file it.

### Gardener (scheduled)
The `gardener` skill runs unattended on a schedule (cron locally or routine in the cloud). It:
1. Pulls latest from git
2. Reads `meta/gardener-rules.md` for current heuristics
3. Processes inbox → atomic notes with proper frontmatter and wiki-links
4. Maintains backlinks (finds plain-text mentions that should be `[[linked]]`)
5. Dedupes near-duplicates
6. Updates MOCs with recent activity
7. Decays old daily notes into monthly summaries
8. Commits with `gardener:` prefix and pushes

The gardener is the agent. Cron/routine is just the alarm clock.

## Voice profile

Separate from `soul.md` (which controls how the agent responds *to* the user), `meta/voice.md` documents how the user actually writes. It's populated by the `garden-voice` skill, which samples the user's sent messages from Slack (or other configured sources), redacts proper nouns/numbers/URLs, synthesizes style patterns, and anchors them with short example snippets.

Used whenever the agent drafts something *as* the user — Slack replies, emails, PRs, tweets, blog posts. `soul.md` instructs the agent to load `voice.md` first for any such task.

**Load-on-demand.** Voice doesn't get injected by the `SessionStart` hook (would bloat context for tasks that don't need it). The agent reads it only when a drafting task surfaces.

Per the source material, having a calibrated voice profile is reportedly the single biggest output-quality multiplier for any drafting work. Sampling actual messages beats abstract self-description by a wide margin.

## Why hooks instead of skills-as-commands

A second brain that requires manual invocation isn't a brain — it's a filing cabinet. Hooks make recall and capture *automatic*. You never type `/recall` or `/capture` in normal use; you talk to Claude as usual, and the garden is in the loop.

Skills still exist as the **library functions** that hooks (and routines) call. They're also the manual escape hatch when automation misses something.

## Local vs cloud execution

| Concern | Local (Claude Code) | Cloud (Cowork / routine) |
|---|---|---|
| Session-start recall | `SessionStart` hook (this repo) | N/A — Cowork loads context differently |
| End-of-session capture | `Stop` hook (this repo) | N/A |
| Gardener | Local cron + headless `claude -p` | Routine via `mcp__scheduled-tasks` or `schedule` skill |
| Vault access | Direct local FS | GitHub plugin reads/writes the same git repo |

Vault-in-git is the bridge: both environments operate on the same source of truth, just via different access paths.

## Why Obsidian

The vault is plain markdown, so any editor works. Obsidian's value is the **graph view + backlinks panel** for visualizing the link structure the LLM is maintaining. You see your garden.

## Memory vs vault

The gardenkit vault complements (not replaces) Claude Code's auto memory at `~/.claude/projects/<project>/memory/`:

| Auto memory | Vault |
|---|---|
| Quick *facts* about user/feedback/projects/references | Full notes, decisions, learnings, project state |
| Indexed by `MEMORY.md` (≤200 lines) | Indexed by `00-index.md` + wiki-links |
| Always loaded into Claude Code context | Loaded via SessionStart hook |
| One-line entries | Multi-paragraph atomic notes |

Use both. Memory for "what's true about you"; vault for "what you know and are working on."
