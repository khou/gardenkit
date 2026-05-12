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
   │  (you)  │         │  or Codex   │       │   (cron)    │
   └─────────┘         └─────────────┘       └─────────────┘
                          ↑       ↑                ↑
                    skills/hooks skills       cron schedule
                                      (claude -p or codex exec)
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
3. Symlink `skills/garden-*` and `skills/gardener` into `~/.claude/skills/` and `~/.codex/skills/`.
4. Wire the `SessionStart` hook in `~/.claude/settings.json` so vault context loads at session start. Capture extraction from past sessions runs on the gardener's cron schedule (see [docs/SCHEDULING.md](docs/SCHEDULING.md)), not as a `SessionEnd` hook. Codex loads the same skills from `~/.codex/skills/`; see [docs/CODEX.md](docs/CODEX.md).
5. Make `scripts/*.sh` executable.
6. Ask whether to enable `GARDENER_AUTO_APPROVE=1` in `~/.zshrc` so the cron-driven gardener can run unattended (default: off; you can enable later).
7. Print next steps. If your existing meta files differ from the latest templates, the installer prints a heads-up; the gardener reconciles content drift on its next run.

It will **not** overwrite existing files in your vault or remove anything.

## Next steps after install

1. **Fill `~/garden/meta/user.md`** by asking Claude or Codex to interview you (15 questions).
2. **Bootstrap your voice profile.** Ask Claude or Codex to "init my voice from Slack" (invokes the `garden-voice` skill). Pulls your sent messages, synthesizes patterns into `meta/voice.md`. Loaded on-demand whenever the agent drafts in your voice.
3. **Bootstrap your knowledge graph from connected data sources.** Ask Claude or Codex to "init my garden from connected sources" (invokes the `garden-bootstrap` skill). Surveys which MCPs are connected (Gmail, Google Drive, Slack are most common), then pulls people, projects, decisions, transcripts, investor / customer state, and writes them as atomic notes and people files. The skill also asks which sources the gardener should keep refreshing on every scheduled run, and writes that decision to `meta/refresh-sources.md`. After the pull, the skill suggests additional data sources you might want to connect for richer context, for example:
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
5. **Log in to your headless agent CLI** so the scheduled gardener can run without a TTY. For Claude:
   ```bash
   claude /login
   ```
   This stores OAuth tokens that the cron-spawned `claude -p` will read. Without this, the gardener fails with `Not logged in · Please run /login` in `~/garden/.gardener-log`. If you have an `ANTHROPIC_API_KEY` exported in your shell, unset it first; the CLI prefers env-var auth over your subscription, and cron will bill that key instead of using your Claude subscription.
   For Codex-based gardening:
   ```bash
   codex login
   ```
   Then use `scripts/gardener-run-codex.sh`.
6. **Schedule the gardener** via local cron (or optionally a cloud routine), see [docs/SCHEDULING.md](docs/SCHEDULING.md). If you skipped step 3, populate `meta/refresh-sources.md` first (the template has examples) so the gardener's external-refresh phase has something to pull. For Codex-specific notes, see [docs/CODEX.md](docs/CODEX.md).

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
│   ├── session-start.sh         ← Claude SessionStart hook: pull, inject index/identity
│   ├── extract-new-transcripts.sh ← Gardener cron: scan transcripts since last run
│   ├── extract-to-inbox.sh      ← Per-transcript extractor invoked by the above
│   ├── gardener-run.sh          ← Claude cron runner
│   └── gardener-run-codex.sh    ← Codex cron runner
├── templates/                   ← seed files copied into a fresh vault
│   ├── 00-index.md
│   ├── README.md
│   ├── meta/{user,soul,gardener-rules,derived-taxonomies,migration-state,refresh-sources}.md
│   └── projects/EXAMPLE.md
└── docs/
    ├── ARCHITECTURE.md          ← the design and reasoning
    ├── SCHEDULING.md            ← cron setup (and optional routines)
    └── CODEX.md                 ← Codex install + scheduling notes
```

## License

MIT.
