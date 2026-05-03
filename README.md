# gardenkit

An LLM-tended second brain. Plain markdown vault, atomic notes, wiki-links, Obsidian-readable, agent-maintained.

This repo is the **framework** — skills, scripts, templates, install. Your actual notes live in a separate (private) vault repo that this scaffolds.

## Philosophy

A second brain works when:
1. **Capture is frictionless** — drop a thought in, stop thinking about it.
2. **Recall is automatic** — relevant past notes surface when you start a session, without asking.
3. **Maintenance is unattended** — an agent files, links, dedupes, and summarizes on a schedule. You never organize manually.

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
   │ Obsidian│         │ Claude Code │       │  Routine /  │
   │  (you)  │         │   + hooks   │       │ cloud agent │
   └─────────┘         └─────────────┘       └─────────────┘
                          ↑       ↑                ↑
                    SessionStart  Stop          schedule
                       (recall) (capture)      (gardener)
```

- **Capture** writes to `inbox/` — fire-and-forget.
- **Recall** runs at session start; injects relevant notes into Claude's context automatically.
- **Gardener** runs on a schedule; processes `inbox/`, links notes, dedupes, summarizes, commits, pushes.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the long version.

## Install

```bash
git clone https://github.com/<you>/gardenkit.git ~/github/gardenkit
cd ~/github/gardenkit
./install.sh
```

The installer is idempotent. It will:

1. Create `~/garden/` (your private vault) if missing, seeded from `templates/`.
2. Symlink `skills/garden-*` into `~/.claude/skills/`.
3. Wire a `SessionStart` hook in `~/.claude/settings.json` pointing at `scripts/session-start.sh`.
4. Initialize git in `~/garden/` if not already.
5. Print next steps.

It will **not** overwrite existing files in your vault or remove anything.

## Next steps after install

1. **Fill `~/garden/meta/user.md`** by asking Claude to interview you (15 questions).
2. **Push your vault to a private GitHub repo:**
   ```bash
   cd ~/garden
   git remote add origin git@github.com:<you>/garden.git
   git push -u origin main
   ```
3. **Schedule the gardener** as a routine (cloud) or local cron — see [docs/SCHEDULING.md](docs/SCHEDULING.md).

## Layout

```
gardenkit/
├── README.md                    ← this file
├── install.sh                   ← idempotent installer
├── skills/
│   ├── garden-capture/SKILL.md   ← drop a thought into inbox/
│   ├── garden-recall/SKILL.md    ← search the vault, surface notes
│   └── gardener/SKILL.md  ← scheduled maintenance
├── scripts/
│   ├── session-start.sh         ← hook: pull, inject index/identity
│   └── gardener-run.sh          ← invoked by routine/cron
├── templates/                   ← seed files copied into a fresh vault
│   ├── 00-index.md
│   ├── README.md
│   ├── meta/{user,soul,gardener-rules}.md
│   └── projects/EXAMPLE.md
└── docs/
    ├── ARCHITECTURE.md          ← the design and reasoning
    └── SCHEDULING.md            ← cron vs routines, examples
```

## License

MIT.
