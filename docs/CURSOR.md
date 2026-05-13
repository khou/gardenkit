# Using gardenkit with Cursor

Cursor reads the same vault Claude does. The gardener stays on the Claude side: it runs on a schedule, maintains the vault, and pushes the result. Cursor consumes the maintained vault for recall, and its sessions get captured into `inbox/` by the same gardener pass that scans Claude transcripts. **You don't run a separate Cursor gardener.**

The gardener runs as `claude -p`. If you have Claude Code Desktop, prefer setting it up as a Local Routine (free with your subscription, no auth headaches). If you're Cursor-only, the cron path requires `ANTHROPIC_API_KEY` and bills against your API account — see [docs/SCHEDULING.md](SCHEDULING.md).

```bash
./install.sh
```

The installer wires two things for Cursor:

1. **`sessionStart` hook** at `~/.cursor/hooks.json` (user-global, fires in every Cursor project):

    - `sessionStart` → `scripts/session-start.sh` (pulls latest, injects vault index + identity into the new conversation)

   This is the same script Claude Code's `SessionStart` hook uses. It auto-detects Cursor via the `$CURSOR_VERSION` env var (which Cursor sets on every hook invocation) and emits JSON `{additional_context: "..."}` instead of Claude's plain text — no flag needed.

   gardenkit does **not** wire Cursor's `sessionEnd` or `preCompact`. See "Why no end-of-session hook?" below.

2. **Project rules** at `~/garden/.cursor/rules/*.mdc` (symlinks to each skill's `SKILL.md`). When you open the vault as a project in Cursor, the agent sees `garden-capture`, `garden-recall`, etc. as "Agent Requested" rules and uses them conversationally.

If your vault lives somewhere other than `~/garden`, set `GARDEN_VAULT` before running the installer:

```bash
GARDEN_VAULT=/path/to/vault ./install.sh
```

## Architecture: Claude maintains, Cursor consumes

```
                  ┌─────────────────────┐
   schedule ────▶ │  Claude gardener    │ ──▶ writes ~/garden, pushes
                  │  (Desktop Routine   │
                  │   or cron fallback) │
                  └──────────┬──────────┘
                             │
                  scans ~/.claude/projects + ~/.cursor/projects
                             │ for new transcripts, extracts captures
                             ▼
                  ┌─────────────────────┐
   Cursor   ────▶ │  ~/garden (vault)   │ ◀──── read on sessionStart
   session  ◀──── │  plain markdown     │
                  └─────────────────────┘
```

One canonical maintenance loop. Cursor is a reader, and its transcripts are an input the gardener consumes asynchronously.

## Hook behavior

**sessionStart.** The hook script pulls the latest vault from git, then prints the contents of `00-index.md`, `meta/user.md`, and `meta/soul.md` wrapped in JSON as `{additional_context: "..."}`. Cursor (1.7+) injects this into the conversation's initial system context.

> ⚠️ There's a known bug in some recent Cursor builds where `sessionStart`'s `additional_context` is accepted but not delivered to the agent (see [forum thread](https://forum.cursor.com/t/sessionstart-hook-additional-context-is-never-injected-into-agents-initial-system-context/158452)). The git-pull side effect still runs, and you can fall back by asking the agent to "use garden-recall" at the start of a conversation if vault context is missing.

## Capture: handled by the scheduled gardener, not a Cursor hook

When the gardener fires (local routine or cron fallback), it runs `scripts/extract-new-transcripts.sh` before the main LLM pass. The scanner walks two directories:

- `~/.claude/projects/**/*.jsonl` (Claude Code sessions)
- `~/.cursor/projects/<workspace>/agent-transcripts/<uuid>/*.jsonl` (Cursor sessions — undocumented internal as of 2026-05, may change. Override with `GARDENKIT_CURSOR_PROJECTS_DIR=/new/path` if Cursor relocates it.)

It picks up transcripts whose mtime is between the last-extract checkpoint and a settle cutoff (default: skip anything modified within the last 10 minutes, since those are in-progress). Each candidate is fed to `scripts/extract-to-inbox.sh`, which reads user + assistant text, runs it through `claude -p` with a focused extraction prompt, and writes one inbox file per noteworthy item. The two transcript formats differ only in the field name for message role (Claude: `type`, Cursor: `role`); the parser handles both.

State lives at `~/.cache/gardenkit/last-extract-epoch`. Sessions whose cwd or workspace slug encodes a path under the vault are skipped (those are the gardener's own runs, which would round-trip).

## Why no end-of-session hook?

gardenkit originally wired Claude's `SessionEnd` and `PreCompact` to the extractor directly, and the Cursor support's first cut mirrored that with `sessionEnd` / `preCompact`. That design produced a fan-out bug: every `claude -p` worker the extractor spawned was itself a Claude Code session whose own `SessionEnd` re-fired the hook, with no concurrency cap. Observed >280 stuck workers in practice (commit f7e222e).

The cron-scan approach decouples extraction from session lifecycle, which removes the recursion surface entirely. Cursor sessions don't fan out the same way (they don't spawn Cursor sub-sessions), but keeping a single canonical extraction path for both clients is simpler and means new Cursor sessions wait until the next gardener tick for captures — same lag as new Claude sessions.

## Everyday use

With the vault open in Cursor, ask the agent conversationally:

- "capture this for the garden: ..."
- "what did I decide about ..."
- "init my garden from connected sources"

For sessions you don't explicitly capture in, the gardener picks them up later from `~/.cursor/projects/`.

## Caveats

- **sessionStart context injection bug.** See above. Track [the issue](https://forum.cursor.com/t/sessionstart-hook-additional-context-is-never-injected-into-agents-initial-system-context/158452).
- **Capture has a lag.** Cursor sessions don't write to `inbox/` immediately; they're picked up on the next gardener cron tick (default every 4 hours). For in-the-moment capture, ask the agent to use `garden-capture` directly.
- **Rules are scoped to the vault.** When working in another Cursor project, the rules don't load. The `sessionStart` hook still fires globally (because it's in `~/.cursor/hooks.json`), so recall works everywhere. If you want the `garden-capture` rule available in another project, manually symlink:
  ```bash
  mkdir -p .cursor/rules
  ln -s ~/github/gardenkit/skills/garden-capture/SKILL.md .cursor/rules/garden-capture.mdc
  ```

## Hook parity table

| Event | Claude Code | Cursor | What gardenkit wires |
|---|---|---|---|
| Session start, inject vault context | `SessionStart` | `sessionStart` | `scripts/session-start.sh` (auto-detects Cursor via `$CURSOR_VERSION`) |
| Session end / pre-compact capture | (not wired; cron-scan instead) | (not wired; cron-scan instead) | gardener cron runs `scripts/extract-new-transcripts.sh`, which scans both Claude and Cursor transcript dirs |
| Schedule the gardener | Desktop Local Routine (default) or cron + `gardener-run.sh` | (Claude maintains the vault) | cron + `gardener-run.sh` with `ANTHROPIC_API_KEY` |
