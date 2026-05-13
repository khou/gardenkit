# gardenkit

An LLM-tended second brain. Plain markdown vault, atomic notes, wiki-links, Obsidian-readable, agent-maintained.

Inspired by [Andrej Karpathy](https://x.com/karpathy)'s thinking on LLM-tended notes.

This repo is the **framework**: skills, scripts, templates, install. Your actual notes live in a separate (private) vault repo that this scaffolds.

## Philosophy

A second brain works when:
1. **Capture is frictionless**: drop a thought in, stop thinking about it.
2. **Recall is automatic**: relevant past notes surface when you start a session, without asking.
3. **Maintenance is unattended**: an agent files, links, dedupes, and summarizes on a schedule. You never organize manually.

This system gives you all three. The vault is plain markdown so Obsidian renders the graph and you stay portable forever.

## Architecture

```
                     ┌──────────────────┐
                     │  ~/garden (vault) │  ← private repo, your data
                     │   markdown +     │
                     │   wiki-links     │
                     └────────┬─────────┘
                              │ read/write
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼────┐         ┌──────▼──────┐       ┌──────▼──────┐
   │ Obsidian│         │ Claude Code │       │  gardener   │
   │  (you)  │         │   / Cursor  │       │ (scheduled) │
   └─────────┘         └─────────────┘       └─────────────┘
                          ↑       ↑                ↑
                    skills/hooks  rules     Desktop Routine
                                            or cron + API key
```

- **Capture** writes to `inbox/`: fire-and-forget.
- **Recall** runs at session start; injects relevant notes into Claude's context automatically.
- **Gardener** runs on a schedule. Each pass pulls diffs from connected sources (Gmail, Drive, Slack, etc.) into `inbox/`, then processes inbox, links notes, dedupes, summarizes, and commits + pushes.

The gardener is **read-only on external sources** by contract: it pulls from MCPs but never sends email, posts Slack, or modifies Drive files. All writes land in `~/garden/` (your private vault).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the long version.

## Install

```bash
git clone https://github.com/<you>/gardenkit.git ~/github/gardenkit
cd ~/github/gardenkit
./install.sh
```

The installer is idempotent. It will:

1. Create `~/garden/` (your private vault) if missing, seeded from `templates/`. On re-run, top up missing meta files from the latest templates without overwriting your customizations (`cp -n`).
2. Initialize git in `~/garden/` if not already.
3. Symlink `skills/garden-*` and `skills/gardener` into `~/.claude/skills/`, and mirror them as `.mdc` rules under `~/garden/.cursor/rules/` for Cursor.
4. Wire `SessionStart` hooks so vault context loads when a session starts:
   - Claude: `SessionStart` in `~/.claude/settings.json`.
   - Cursor (1.7+): `sessionStart` in `~/.cursor/hooks.json` (user-global). Same `scripts/session-start.sh`; the script auto-detects Cursor via `$CURSOR_VERSION` and emits the JSON Cursor expects. See [docs/CURSOR.md](docs/CURSOR.md).
   Capture extraction from past sessions runs on the gardener's schedule (see [docs/SCHEDULING.md](docs/SCHEDULING.md)), not as a `SessionEnd` hook — the old hook design fanned out into a recursion bug.
5. Make `scripts/*.sh` executable.
6. Ask which scheduling path you want — Claude Code Desktop Local Routine (default, free with subscription) or cron + `ANTHROPIC_API_KEY` (Cursor-only / no-Desktop, API-billed) — and print the appropriate setup instructions.
7. Print next steps. If your existing meta files differ from the latest templates, the installer prints a heads-up; the gardener reconciles content drift on its next run.

It will **not** overwrite existing files in your vault or remove anything.

## Next steps after install

1. **Fill `~/garden/meta/user.md`** by asking Claude or Cursor to interview you (15 questions).
2. **Bootstrap your voice profile.** Ask Claude or Cursor to "init my voice from Slack" (invokes the `garden-voice` skill). Pulls your sent messages, synthesizes patterns into `meta/voice.md`. Loaded on-demand whenever the agent drafts in your voice.
3. **Bootstrap your knowledge graph from connected data sources.** Ask Claude or Cursor to "init my garden from connected sources" (invokes the `garden-bootstrap` skill). Surveys which MCPs are connected (Gmail, Google Drive, Slack are most common), then pulls people, projects, decisions, transcripts, investor / customer state, and writes them as atomic notes and people files. The skill also asks which sources the gardener should keep refreshing on every scheduled run, and writes that decision to `meta/refresh-sources.md`. After the pull, the skill suggests additional data sources you might want to connect for richer context, for example:
   - Meeting transcript services (Granola, Fireflies, Otter, Zoom AI, Read.ai)
   - CRM / sales pipeline (HubSpot, Salesforce, Close, Attio)
   - Issue tracker / project management (Linear, Jira, Asana, Notion, ClickUp)
   - Code (GitHub PRs, issues, commits)
   - Customer support (Intercom, Zendesk, Freshdesk, Plain)
   - Calendar (Google Calendar, Outlook)
   - Documents beyond Drive (Notion, Confluence, Quip)
   - Chat beyond Slack (Discord, Teams)
   - Voice notes / dictation (Apple Voice Memos plus Whisper)
   - Read-later / web research (Pocket, Instapaper, Readwise)

   The skill is idempotent. Re-run as `refresh` later to top up with new data since the last run.
4. **Push your vault to a private GitHub repo:**
   ```bash
   cd ~/garden
   git remote add origin git@github.com:<you>/garden.git
   git push -u origin main
   ```
5. **Schedule the gardener.** Two paths — pick what fits in [docs/SCHEDULING.md](docs/SCHEDULING.md):
   - **Default**: a Claude Code Desktop Local Routine, every 4 hours, free with your Pro/Max subscription. Ask Claude in any Desktop session to "set up the gardener routine" and approve the dialog.
   - **Fallback**: cron + `ANTHROPIC_API_KEY` for Cursor-only users, or Claude users who don't want Desktop pinned open. Note: API keys bill against your API account, which is separate from Pro/Max — the subscription does **not** include API credits.

   If you skipped step 3, populate `meta/refresh-sources.md` first (the template has examples) so the gardener's external-refresh phase has something to pull. Cursor specifics: [docs/CURSOR.md](docs/CURSOR.md).

## Layout

```
gardenkit/
├── README.md                    ← this file
├── install.sh                   ← idempotent installer
├── skills/
│   ├── garden-capture/SKILL.md   ← drop a thought into inbox/
│   ├── garden-recall/SKILL.md    ← search the vault, surface notes
│   ├── garden-voice/SKILL.md     ← derive voice profile from your real messages
│   ├── garden-bootstrap/SKILL.md ← initial pull from connected data sources (Gmail/Drive/Slack)
│   └── gardener/SKILL.md         ← scheduled maintenance
├── scripts/
│   ├── session-start.sh         ← SessionStart hook (Claude plain text; Cursor JSON via $CURSOR_VERSION auto-detect)
│   ├── extract-new-transcripts.sh ← Scheduled gardener: scan transcripts since last run
│   ├── extract-to-inbox.sh      ← Per-transcript extractor invoked by the above
│   └── gardener-run.sh          ← Cron fallback runner (requires ANTHROPIC_API_KEY)
├── templates/                   ← seed files copied into a fresh vault
│   ├── 00-index.md
│   ├── README.md
│   ├── scheduled-task-gardener.md ← canonical prompt body for the scheduled gardener (shared by Desktop Routine and cron paths)
│   ├── meta/{user,soul,gardener-rules,derived-taxonomies,migration-state,refresh-sources}.md
│   └── projects/EXAMPLE.md
└── docs/
    ├── ARCHITECTURE.md          ← the design and reasoning
    ├── SCHEDULING.md            ← Desktop Local Routine (default), cron fallback, cloud option
    └── CURSOR.md                ← Cursor install + scheduling notes
```

## License

MIT.
