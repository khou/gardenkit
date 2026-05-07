# Scheduling the gardener

The gardener is one LLM agent that runs through all phases each pass: pull external diffs into `inbox/`, then file, link, dedupe, summarize, commit. Cron just triggers it.

## Default: local cron

A cron entry fires `scripts/gardener-run.sh`, which invokes `claude -p` headlessly. Uses your existing Claude Code subscription: no separate billing.

### Prerequisites

1. **Log in to Claude headlessly** so the cron-spawned `claude -p` finds OAuth tokens:
   ```bash
   claude /login
   ```
   Skip this and the gardener will silently fail with `Not logged in · Please run /login` in the log.

2. **Unset any `ANTHROPIC_API_KEY` in your shell config.** The CLI prefers env-var auth over your subscription. If a key is set and unfunded, cron runs hit `Credit balance is too low` instead of using your subscription. Check with `echo "${ANTHROPIC_API_KEY:+set}"` and remove from `~/.zshrc` if present.

3. **Decide on autonomous mode.** Cron has no TTY, so the gardener stops at every permission prompt unless you opt in to `--dangerously-skip-permissions`. The script reads `GARDENER_AUTO_APPROVE` to decide:
   ```bash
   # Add to ~/.zshrc to enable:
   export GARDENER_AUTO_APPROVE=1
   ```
   `install.sh` prompts you for this at setup. Without it, the gardener will plan changes each run but block before executing. With it, the gardener has free rein inside `~/garden`, on git operations, and on any connected MCPs (Gmail, Drive, Slack, etc.).

   **The gardener's contract is read-only on external sources** (it pulls from MCPs but never sends email, posts Slack, modifies Drive, etc.). The contract is a skill-level rule the LLM follows; `--dangerously-skip-permissions` does not enforce it at the harness layer. If your global MCPs include high-stakes write tools, consider scoping them to read-only at the MCP layer or moving them out of `~/.claude/settings.json` so cron-spawned Claude can't see them.

4. **Populate `~/garden/meta/refresh-sources.md`** before scheduling. The gardener's external-refresh phase reads this file as the source of truth for which sources to pull from and at what scope; if it has no "Active" entries, the refresh phase is skipped. Two ways to populate it:

   - **Easy path**: run `garden-bootstrap` in `init` mode interactively. The skill asks you, per surveyed source, whether the gardener should keep refreshing it, and writes the file for you.
   - **Manual path**: edit `~/garden/meta/refresh-sources.md` directly. The template includes commented-out examples to copy from.

   Either way, this is where you scope the ongoing pipeline. Edit the file later anytime to add, remove, or rescope sources.

### Setup

Edit your crontab:

```bash
crontab -e
```

Add (every 4 hours, off-minute to avoid stampedes):

```
7 */4 * * * /Users/<you>/github/gardenkit/scripts/gardener-run.sh
```

Verify it's installed:

```bash
crontab -l | grep gardener
```

That single entry covers everything: each gardener pass first refreshes from connected sources, then files inbox, links, dedupes, and so on. The brain stays fresh on the same cadence as the cleanup. (See [docs/ARCHITECTURE.md](ARCHITECTURE.md) or [skills/gardener/SKILL.md](../skills/gardener/SKILL.md) for the full phase list.)

### Cadences worth considering

- **Every 4 hours**: good default. Keeps the brain reasonably fresh without burning through subscription tokens. External refresh runs on the same cadence, frequent enough to capture the day's email/Slack/Drive activity within hours.
- **Daily, 3 AM**: minimal pass. Good if you don't lean on auto-ingestion much and mostly capture inline.
- **Hourly or 30 min**: aggressive. Only worth it if you're actively writing to inbox throughout the day or live in fast-moving channels.
- **Weekly, Sunday**: weekly review synthesis (optional second cron entry with `--review` flag, or a dedicated script).

### Notes

- Cron has a minimal PATH. `gardener-run.sh` sources `~/.zshrc` to find `claude`. If you're on bash, edit the script.
- Your laptop must be awake/on for cron to fire. If it sleeps through 3 AM, the run is skipped (next firing picks it up).
- The MCPs available to the cron-spawned `claude -p` come from your global `~/.claude/settings.json`. If your interactive Claude can see Gmail/Drive/Slack but cron can't, the MCP config is project-scoped; move the relevant entries to global settings.
- If you want runs even while traveling without your laptop: see "Optional: routines" below.

## Optional: routines (cloud)

If you genuinely need always-on execution and accept the per-run billing, you can use Anthropic-hosted routines via the `schedule` skill in Claude Code.

**Tradeoff:** routines are billed agent runs separate from your Claude Code subscription. Local cron uses what you're already paying for.

Recommended only if:
- You travel often and the laptop is off for days
- You want very high cadence (cron is fine for hourly+, routines also work)
- You want to garden multiple vaults in parallel

## Verifying the gardener ran

Each pass writes to `~/garden/.gardener-log` and leaves a `gardener:` commit:

```bash
tail ~/garden/.gardener-log
cd ~/garden && git log --grep '^gardener:' --oneline | head
```

## Troubleshooting

**`Not logged in · Please run /login` in log:** OAuth tokens aren't where headless `claude -p` looks. Run `claude /login` from a regular terminal, then wait for the next cron firing.

**`Credit balance is too low` in log:** an `ANTHROPIC_API_KEY` is set and the CLI is using it instead of your subscription. Check `echo "${ANTHROPIC_API_KEY:+set}"`, then remove the export from `~/.zshrc` (or `~/.zshenv`, `~/.zprofile`) and restart your shell.

**`claude: command not found` in log:** the cron PATH isn't picking up Claude. Edit `gardener-run.sh` to source the right profile, or set PATH explicitly at the top.

**`git push failed`:** the cron user can't auth to GitHub. Make sure your SSH key works headlessly (`ssh -T git@github.com` from a fresh shell), or use a credential helper.

**Gardener never commits anything:** check the log. The gardener is conservative: if there's nothing in `inbox/`, no external diffs since the last run, and no link/dedupe work to do, it'll exit cleanly with no changes.

**External refresh phase keeps getting skipped:** the gardener skips its external-refresh phase if `~/garden/meta/refresh-sources.md` is missing or has no "Active" entries. Either run `garden-bootstrap` in `init` mode interactively (it'll ask which sources to refresh and write the file), or edit `~/garden/meta/refresh-sources.md` by hand using the template's examples.

**Refresh phase runs but writes nothing:** check `~/garden/meta/refresh-sources.md` lists the sources you expect under "Active". If it does, the cron-spawned Claude probably can't see the relevant MCPs; those come from your global `~/.claude/settings.json`, not project-scoped settings. Move the relevant MCP entries to global settings if needed.

**Log file never gets created at all (no `~/garden/.gardener-log`):** cron isn't reaching the script's first log write. Most likely macOS Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`. Verify cron itself is firing with `log show --predicate 'process == "cron"' --last 1h | grep gardener`.
