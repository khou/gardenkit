# Using gardenkit with Codex

gardenkit works with Codex by installing the same skills into Codex's skill directory:

```bash
./install.sh
```

The installer symlinks:

- `skills/garden-capture`
- `skills/garden-recall`
- `skills/garden-voice`
- `skills/garden-bootstrap`
- `skills/gardener`

into `~/.codex/skills/` by default. If you keep Codex state somewhere else, set `CODEX_HOME` before running the installer:

```bash
CODEX_HOME=/path/to/codex-home ./install.sh
```

Restart Codex after install so the new skills are discovered.

## Everyday use

Once installed, Codex can use the skills conversationally:

- "capture this for the garden: ..."
- "what did I decide about ..."
- "init my garden from connected sources"
- "run the gardener skill"

The skills read and write `~/garden` unless `GARDEN_VAULT` is set.

## Scheduled gardening

For local cron, use the Codex runner:

```cron
7 */4 * * * /Users/<you>/github/gardenkit/scripts/gardener-run-codex.sh
```

The runner invokes:

```bash
codex exec -C ~/garden --full-auto "<gardener prompt>"
```

By default, Codex runs with workspace-write sandboxing rooted at `~/garden`. If your vault workflow needs unrestricted local access and you understand the risk, set:

```bash
export CODEX_GARDENER_FULL_ACCESS=1
```

Then `gardener-run-codex.sh` uses `--dangerously-bypass-approvals-and-sandbox`.

You can also schedule the same work with a Codex app automation instead of cron. Use this prompt:

```text
Run the gardener skill on the vault at ~/garden. Process inbox, maintain links, dedupe, update MOCs, and commit + push. Be thorough but conservative. When in doubt, leave a NOTE blockquote rather than guessing.
```

## Hook parity

Claude Code supports SessionStart, SessionEnd, and PreCompact hooks, and gardenkit wires those automatically in `~/.claude/settings.json`.

Codex currently gets the garden behavior through installed skills and scheduled runs. If you want session-start recall in a Codex conversation, ask:

```text
Use garden-recall for the current project context.
```

For capture, ask Codex to use `garden-capture`, or schedule the gardener to process manual inbox files.
