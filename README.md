# gardenkit

An LLM-tended second brain. Plain markdown vault, atomic notes, wiki-links, Obsidian-readable, agent-maintained.

Inspired by [Andrej Karpathy](https://x.com/karpathy)'s thinking on LLM-tended notes.

This repo is the **framework**: skills, scripts, templates, install. Your actual notes live in a separate (private) vault repo that this scaffolds.

## Philosophy

A second brain works when:
1. **Capture is explicit but cheap**: you say "capture X" and it's in. Nothing gets written without you asking.
2. **Recall is automatic**: relevant past notes surface when you start a session, without asking.
3. **Maintenance is unattended**: an agent files, links, dedupes, and summarizes on a schedule. You never organize manually.

The vault is plain markdown so Obsidian renders the graph and you stay portable forever.

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

- **Capture** is explicit only: ask the agent to "capture X" in a session and `garden-capture` drops it in `inbox/`. Nothing else writes to `inbox/`.
- **Recall** runs at session start; injects relevant notes into Claude's context automatically.
- **Gardener** runs on a schedule. Each pass files inbox content into atomic notes, links them, dedupes, summarizes, and commits + pushes.
- **Bootstrap** (optional, one-shot): when you explicitly invoke it, `garden-bootstrap` surveys what's connected (Gmail/Drive/Slack/etc.), proposes a plan, asks you to confirm, and seeds the vault from those sources. It never runs unattended — you choose when (or whether) to run it.

The gardener writes only to `~/garden/` (your private vault) and its git remote. It does **not** reach out to external services on its own, and does **not** scrape your past Claude Code or Cursor sessions. The only paths that write to the vault are your explicit `garden-capture` invocations and your explicit `garden-bootstrap` runs.

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
   No `SessionEnd` / `PreCompact` hook is wired. Capture is explicit-only.
5. Make `scripts/*.sh` executable.
6. Ask which scheduling path you want — Claude Code Desktop Local Routine (default, free with subscription) or cron + `ANTHROPIC_API_KEY` (Cursor-only / no-Desktop, API-billed) — and print the appropriate setup instructions.
7. Print next steps. If your existing meta files differ from the latest templates, the installer prints a heads-up; the gardener reconciles content drift on its next run.

It will **not** overwrite existing files in your vault or remove anything.

## Next steps after install

1. **Fill `~/garden/meta/user.md`** by asking Claude or Cursor to interview you (15 questions).
2. **Bootstrap your voice profile.** Ask Claude or Cursor to "init my voice from Slack" (invokes the `garden-voice` skill). Pulls your sent messages, synthesizes patterns into `meta/voice.md`. Loaded on-demand whenever the agent drafts in your voice.
3. **(Optional) Seed the vault from connected sources.** If you want to pre-populate the vault with people, projects, and decisions from Gmail/Drive/Slack/etc., ask the agent to "init my garden from connected sources" (invokes `garden-bootstrap`). It surveys what's there, proposes a plan, and only pulls what you confirm. One-shot — never runs unattended. You can re-invoke it as `refresh` later to top up.
4. **Push your vault to a private GitHub repo:**
   ```bash
   cd ~/garden
   git remote add origin git@github.com:<you>/garden.git
   git push -u origin main
   ```
5. **Schedule the gardener.** Two paths — pick what fits in [docs/SCHEDULING.md](docs/SCHEDULING.md):
   - **Default**: a Claude Code Desktop Local Routine, every 4 hours, free with your Pro/Max subscription. Ask Claude in any Desktop session to "set up the gardener routine" and approve the dialog.
   - **Fallback**: cron + `ANTHROPIC_API_KEY` for Cursor-only users, or Claude users who don't want Desktop pinned open. Note: API keys bill against your API account, which is separate from Pro/Max — the subscription does **not** include API credits.

   Cursor specifics: [docs/CURSOR.md](docs/CURSOR.md).

## Layout

```
gardenkit/
├── README.md                    ← this file
├── install.sh                   ← idempotent installer
├── skills/
│   ├── garden-capture/SKILL.md   ← drop a thought into inbox/
│   ├── garden-recall/SKILL.md    ← search the vault, surface notes
│   ├── garden-voice/SKILL.md     ← derive voice profile from your real messages
│   ├── garden-bootstrap/SKILL.md ← optional one-shot seed from connected sources (you invoke; never scheduled)
│   └── gardener/SKILL.md         ← scheduled maintenance
├── scripts/
│   ├── session-start.sh         ← SessionStart hook (Claude plain text; Cursor JSON via $CURSOR_VERSION auto-detect)
│   └── gardener-run.sh          ← Cron fallback runner (requires ANTHROPIC_API_KEY)
├── templates/                   ← seed files copied into a fresh vault
│   ├── 00-index.md
│   ├── README.md
│   ├── scheduled-task-gardener.md ← canonical prompt body for the scheduled gardener (shared by Desktop Routine and cron paths)
│   ├── meta/{user,soul,gardener-rules,derived-taxonomies,migration-state}.md
│   └── projects/EXAMPLE.md
└── docs/
    ├── ARCHITECTURE.md          ← the design and reasoning
    ├── SCHEDULING.md            ← Desktop Local Routine (default), cron fallback, cloud option
    └── CURSOR.md                ← Cursor install + scheduling notes
```

## License

MIT.
