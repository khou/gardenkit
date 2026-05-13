# Using gardenkit with Cursor

Cursor reads the same vault Claude does. The gardener stays on the Claude side: it runs on a schedule, maintains the vault, and pushes the result. Cursor consumes the maintained vault for recall, and writes to `inbox/` only when the user explicitly invokes `garden-capture` in a Cursor session. **You don't run a separate Cursor gardener.**

The gardener runs as `claude -p`. If you have Claude Code Desktop, prefer setting it up as a Local Routine (free with your subscription, no auth headaches). If you're Cursor-only, the cron path requires `ANTHROPIC_API_KEY` and bills against your API account — see [docs/SCHEDULING.md](SCHEDULING.md).

```bash
./install.sh
```

The installer wires two things for Cursor:

1. **`sessionStart` hook** at `~/.cursor/hooks.json` (user-global, fires in every Cursor project):

    - `sessionStart` → `scripts/session-start.sh` (pulls latest, injects vault index + identity into the new conversation)

   This is the same script Claude Code's `SessionStart` hook uses. It auto-detects Cursor via the `$CURSOR_VERSION` env var (which Cursor sets on every hook invocation) and emits JSON `{additional_context: "..."}` instead of Claude's plain text — no flag needed.

   gardenkit does **not** wire Cursor's `sessionEnd` or `preCompact`. Capture is explicit-only: the agent writes to `inbox/` when the user invokes `garden-capture` and not otherwise.

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
                             │ files inbox content into atomic notes
                             ▼
                  ┌─────────────────────┐
   Cursor   ────▶ │  ~/garden (vault)   │ ◀──── read on sessionStart;
   session  ◀──── │  plain markdown     │       write on garden-capture
                  └─────────────────────┘
```

One canonical maintenance loop. Cursor is a reader, and is also a writer to `inbox/` when the user explicitly says so.

## Hook behavior

**sessionStart.** The hook script pulls the latest vault from git, then prints the contents of `00-index.md`, `meta/user.md`, and `meta/soul.md` wrapped in JSON as `{additional_context: "..."}`. Cursor (1.7+) injects this into the conversation's initial system context.

> ⚠️ There's a known bug in some recent Cursor builds where `sessionStart`'s `additional_context` is accepted but not delivered to the agent (see [forum thread](https://forum.cursor.com/t/sessionstart-hook-additional-context-is-never-injected-into-agents-initial-system-context/158452)). The git-pull side effect still runs, and you can fall back by asking the agent to "use garden-recall" at the start of a conversation if vault context is missing.

## Capture is explicit-only

gardenkit does not scan past Cursor or Claude Code sessions, and does not wire any end-of-session hook. The only path that writes to `inbox/` is the user explicitly invoking `garden-capture` in a session ("capture this", "for the garden, ...", etc.). If you don't ask for it, nothing gets captured.

## Everyday use

With the vault open in Cursor, ask the agent conversationally:

- "capture this for the garden: ..."
- "what did I decide about ..."

## Caveats

- **sessionStart context injection bug.** See above. Track [the issue](https://forum.cursor.com/t/sessionstart-hook-additional-context-is-never-injected-into-agents-initial-system-context/158452).
- **Rules are scoped to the vault.** When working in another Cursor project, the rules don't load. The `sessionStart` hook still fires globally (because it's in `~/.cursor/hooks.json`), so recall works everywhere. If you want the `garden-capture` rule available in another project, manually symlink:
  ```bash
  mkdir -p .cursor/rules
  ln -s ~/github/gardenkit/skills/garden-capture/SKILL.md .cursor/rules/garden-capture.mdc
  ```

## Hook parity table

| Event | Claude Code | Cursor | What gardenkit wires |
|---|---|---|---|
| Session start, inject vault context | `SessionStart` | `sessionStart` | `scripts/session-start.sh` (auto-detects Cursor via `$CURSOR_VERSION`) |
| Session end / pre-compact capture | (not wired) | (not wired) | nothing — capture is explicit-only via `garden-capture` |
| Schedule the gardener | Desktop Local Routine (default) or cron + `gardener-run.sh` | (Claude maintains the vault) | cron + `gardener-run.sh` with `ANTHROPIC_API_KEY` |
