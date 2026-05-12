# Architecture

The thinking behind gardenkit.

## Goals

- **Single vault, all topics.** No per-topic directory structure to switch between.
- **LLM-maintained.** You capture; the agent organizes.
- **Obsidian-visualizable.** Plain markdown + wiki-links → graph view, backlinks, tags all work.
- **Portable across environments.** Works in Claude Code, Codex, Cowork/cloud routines, and Obsidian, with the vault in git.

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
    ├── user.md                ← who you are, preferences
    ├── soul.md                ← agent persona
    ├── voice.md               ← your writing style (added by garden-voice; load on demand)
    ├── gardener-rules.md      ← maintenance heuristics
    ├── derived-taxonomies.md  ← gardener-curated derived MOC types (e.g. companies/)
    ├── migration-state.md     ← gardener-tracked schema migration state
    └── refresh-sources.md     ← which external sources the gardener pulls from each pass
```

The gardener may also create top-level **derived-MOC folders** (`companies/`, `vendors/`, etc.) when content crosses the threshold for aggregating. (A MOC, "Map of Content", is an index file that links into a topic; in gardenkit, derived MOCs are agent-curated and regenerated each pass from the atomic notes that mention or are tagged with the topic.) Their type roster lives in `meta/derived-taxonomies.md`.

Folders are *templates*, not topics. A note about a project goes in `notes/` and links to `[[projects/<name>]]`. Backlinks make the project page a live index.

## Atomic notes

Every note: one concept, frontmatter, body, links.

```yaml
---
type: note
tags: [topic1, topic2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
summary: One sentence, ≤140 chars. What you'd learn from reading this.
# Typed edges (when applicable, gardener-maintained):
supersedes:    [decisions/2024-09-old-decision]
depends-on:    [projects/api-rewrite]
contradicts:   [learnings/old-fact]
derived-from:  [inbox/2026-04-30-call-notes]
part-of:       [notes/parent-concept]
---
```

Three rules carry the system:
1. **One concept per file.** Target 50–300 lines; the gardener splits oversized notes.
2. **Link, don't nest.** Plain `[[wiki-links]]` in the body cover the default "related, untyped" case.
3. **Every note has a one-sentence `summary:`.** Recall reads summaries first and only loads bodies when the summary signals it's worth the tokens. The gardener writes summaries when filing inbox captures and refreshes them when bodies materially change.

## Schema design

gardenkit uses four layers of structure. The first three apply to atomic notes; the fourth is an aggregation pattern over them.

1. **Type frontmatter** (`type: note | decision | person | project | daily | learning`): a light enum, broad enough that the gardener can apply it from context without ambiguity. Derived-MOC types extend this enum; see layer 4.
2. **One-sentence `summary:`**: the short hook recall reads first to decide whether to load the body.
3. **Typed edges** in frontmatter: `supersedes`, `depends-on`, `contradicts`, `derived-from`, `part-of`. Populated by the gardener when the relationship is explicit in the source material; left absent otherwise. The first four describe live relationships between vault notes (the hygiene phase validates them); `derived-from` is provenance and may point at deleted inbox captures or external URLs (not validated). Plain `[[wiki-links]]` in the body remain the default for "related, untyped."
4. **Derived MOCs** (agent-curated, regenerated each gardener pass): the gardener notices when a class of entity recurs across atomic notes (companies, vendors, technologies, etc.), introduces a folder for the type, and regenerates a MOC per instance from the underlying notes. The set of derived types is itself emergent: agents introduce, merge, split, and retire types as the vault evolves. Audit trail in [[meta/derived-taxonomies]]. The schema-migration phase keeps existing files in sync as conventions change. Derived MOCs are read-only (regenerated, not edited); to change one, edit the underlying atomic notes.

Why typed edges in addition to wiki-links? Plain links waste retrieval token budget. To know whether following one is worth the cost, the AI has to read the target. Typed edges let recall prune up front: a chain of `supersedes` edges doesn't need full traversal when the query is about current state; a `contradicts` edge always warrants showing both sides; `depends-on` matters only when the query is about prerequisites. This is the same scoped-retrieval win that adjacent systems (PARA, the "Infinite Brain" remix) pursue with heavier 10-edge schemas. We took the five edge types that have clear semantics the gardener can apply without speculation.

What gardenkit deliberately doesn't do: put the user in front of the schema. PARA-style systems require categorizing at write time; "Infinite Brain" extends that with 16 node types and 10 typed edges to maintain by hand. That works for people who sit down to model their knowledge in Obsidian. It doesn't fit gardenkit's premise: capture from where work actually happens (Slack, PRs, sessions), and let the gardener file, summarize, and edge-annotate asynchronously. The schema is for the agent; the user just dumps captures.

The alternatives are honest design choices, not wrong ones. They optimize for a different workflow.

## The three loops

### Recall (session start)
A Claude Code `SessionStart` hook pulls latest from git and prints `00-index.md` + `meta/user.md` + `meta/soul.md` to stdout. Claude Code injects this as additional context for the new session. Codex uses the same recall logic through the installed `garden-recall` skill; ask it to use garden recall when you want vault context at the start of a conversation. The agent then follows wiki-links on demand for deeper context.

### Capture (during/after session)
The `garden-capture` skill writes a raw markdown file into `inbox/`. This can be triggered by:
- The user explicitly: "capture this"
- The gardener cron, which scans Claude Code transcripts ended since the last run and pipes each through the extractor (see below)

`scripts/extract-new-transcripts.sh` is invoked by `gardener-run.sh` before the main gardener LLM pass. It walks `~/.claude/projects/**/*.jsonl`, picks up transcripts whose mtime is between the last-extract checkpoint and a settle cutoff (skipping in-progress sessions), and feeds each one to `scripts/extract-to-inbox.sh`. The per-transcript extractor reads user+assistant text, runs it through `claude -p` with a focused extraction prompt, and writes one inbox file per noteworthy item. Subagent fragments and the gardener's own vault-cwd sessions are filtered out. State lives at `~/.cache/gardenkit/last-extract-epoch`. Codex capture is skill-driven today: ask it to use `garden-capture`, or run the scheduled gardener over manually added inbox files.

This used to be wired as a `SessionEnd` / `PreCompact` hook. That design produced a fan-out bug: every `claude -p` worker is itself a Claude Code session whose own `SessionEnd` re-fired the hook, with no concurrency cap. The cron-scan approach decouples extraction from session lifecycle, which removes the recursion surface entirely.

Tunable via env vars:
- `GARDEN_CAPTURE_MIN_WORDS` (default 200): skip extraction if transcript is shorter
- `GARDEN_CAPTURE_MAX_ITEMS` (default 5): cap captures per transcript
- `EXTRACT_SETTLE_MINUTES` (default 10): skip transcripts modified within the last N min
- `EXTRACT_MAX_PER_RUN` (default 20): cap transcripts processed per cron tick

Inbox files stay raw. The gardener decides what to keep and where to file it.

### Gardener (scheduled)
The `gardener` skill runs unattended on a schedule (cron locally or routine in the cloud). It:
1. Pulls latest from git
2. Reads the authoritative meta files: `meta/gardener-rules.md`, `meta/derived-taxonomies.md`, `meta/migration-state.md`, `meta/refresh-sources.md`
3. Runs schema migration: brings drifted files up to the current convention (capped ~50/run), so a freshly-pulled gardenkit version converges the vault over the next runs
4. External refresh: pulls diffs from connected sources (Gmail, Drive, Slack, etc.) into `inbox/` per the scope in `meta/refresh-sources.md`. Skipped if that file has no "Active" entries.
5. Processes inbox → atomic notes with frontmatter (`type`, `tags`, `created`, `updated`, `summary`, plus typed edges where explicit), and `[[wiki-links]]` in the body
6. Maintains backlinks (finds plain-text mentions that should be `[[linked]]`)
7. Dedupes near-duplicates
8. Maintains summary/size/edge hygiene (backfills missing summaries, splits oversized notes, fixes broken edge targets)
9. Runs a consistency check across the brain: sweeps this-run-touched notes plus a rolling sample of hubs for cross-note contradictions and stale statuses, sets `supersedes:` / `contradicts:` edges or flags ambiguous cases for human review
10. Curates derived taxonomies: regenerates derived MOCs (e.g. `companies/`) from atomic notes; introduces, merges, splits, or retires derived types as content evolves
11. Updates hand-curated MOCs with recent activity
12. Decays old daily notes into monthly summaries
13. Commits with `gardener:` prefix and pushes

The gardener is the agent. Cron/routine is just the alarm clock.

**Contract:** the gardener is **read-only on external sources**. It pulls from connected MCPs (Gmail, Drive, Slack, etc.) but never sends, posts, modifies, or deletes through them. Writes are limited to `~/garden/` and git operations on its remote. Captured content is treated as untrusted data, not instructions; the gardener doesn't follow directives found inside email/Slack/Drive/inbox content. Secrets that slip through get redacted at file time, not silently dropped. The contract is enforced by the LLM following its skill rules; the canonical version lives in `garden-bootstrap`'s "Privacy and safety" section, which the gardener's phase 4 references.

## Voice profile

Separate from `soul.md` (which controls how the agent responds *to* the user), `meta/voice.md` documents how the user actually writes. It's populated by the `garden-voice` skill, which samples the user's sent messages from Slack (or other configured sources), redacts proper nouns/numbers/URLs, synthesizes style patterns, and anchors them with short example snippets.

Used whenever the agent drafts something *as* the user: Slack replies, emails, PRs, tweets, blog posts. `soul.md` instructs the agent to load `voice.md` first for any such task.

**Load-on-demand.** Voice doesn't get injected by the `SessionStart` hook (would bloat context for tasks that don't need it). The agent reads it only when a drafting task surfaces.

Per the source material, having a calibrated voice profile is reportedly the single biggest output-quality multiplier for any drafting work. Sampling actual messages beats abstract self-description by a wide margin.

## Why automation instead of skills-as-commands

A second brain that requires manual invocation isn't a brain: it's a filing cabinet. The `SessionStart` hook (for recall) and the gardener's cron (for capture extraction and filing) make the loop *automatic*. You never type `/recall` or `/capture` in normal use; you talk to Claude as usual, and the garden is in the loop.

Skills still exist as the **library functions** that hooks, the cron, and routines call. They're also the manual escape hatch when automation misses something.

## Local vs cloud execution

| Concern | Claude Code | Codex | Cloud (Cowork / routine) |
|---|---|---|---|
| Session-start recall | `SessionStart` hook (this repo) | `garden-recall` skill on demand | N/A: Cowork loads context differently |
| End-of-session capture | Gardener cron scans new transcripts (this repo) | `garden-capture` skill on demand | N/A |
| Gardener | Local cron + headless `claude -p` | Local cron + `codex exec` | Routine via `mcp__scheduled-tasks` or `schedule` skill |
| Vault access | Direct local FS | Direct local FS | GitHub plugin reads/writes the same git repo |

Vault-in-git is the bridge: both environments operate on the same source of truth, just via different access paths.

## Why Obsidian

The vault is plain markdown, so any editor works. Obsidian's value is the **graph view + backlinks panel** for visualizing the link structure the LLM is maintaining. You see your garden.

## Memory vs vault

The gardenkit vault complements (not replaces) agent-local memory such as Claude Code's auto memory at `~/.claude/projects/<project>/memory/`:

| Auto memory | Vault |
|---|---|
| Quick *facts* about user/feedback/projects/references | Full notes, decisions, learnings, project state |
| Indexed by `MEMORY.md` (≤200 lines) | Indexed by `00-index.md` + wiki-links |
| Always loaded into the agent's local context | Loaded via hook or `garden-recall` |
| One-line entries | Multi-paragraph atomic notes |

Use both. Memory for "what's true about you"; vault for "what you know and are working on."
