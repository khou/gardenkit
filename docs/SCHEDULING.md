# Scheduling the gardener

The gardener is an LLM agent. Cron just triggers it.

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
   `install.sh` prompts you for this at setup. Without it, the gardener will plan changes each run but block before executing. With it, the gardener has free rein inside `~/garden` and on git operations.

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

### Cadences worth considering

- **Every 4 hours**: good default once external ingestion (Gmail/Slack/Drive) is wired up. Keeps the brain reasonably fresh without burning through subscription tokens.
- **Daily, 3 AM**: minimal pass. Good if you mostly capture inline and don't lean on auto-ingestion.
- **Hourly or 30 min**: aggressive — only worth it if you're actively writing to inbox throughout the day.
- **Weekly, Sunday**: weekly review synthesis (optional second cron entry with `--review` flag, or a dedicated script).

### Notes

- Cron has a minimal PATH. `gardener-run.sh` sources `~/.zshrc` to find `claude`. If you're on bash, edit the script.
- Your laptop must be awake/on for cron to fire. If it sleeps through 3 AM, the run is skipped (next day picks it up).
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

**Gardener never commits anything:** check the log. The gardener is conservative: if there's nothing in `inbox/` and no link/dedupe work to do, it'll exit cleanly with no changes.

**Log file never gets created at all (no `~/garden/.gardener-log`):** cron isn't reaching the script's first log write. Most likely macOS Full Disk Access — System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`. Verify cron itself is firing with `log show --predicate 'process == "cron"' --last 1h | grep gardener`.
