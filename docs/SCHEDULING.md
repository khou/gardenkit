# Scheduling the gardener

The gardener is an LLM agent. Cron just triggers it.

## Default: local cron

A cron entry fires `scripts/gardener-run.sh`, which invokes `claude -p` headlessly. Uses your existing Claude Code subscription: no separate billing.

### Setup

Edit your crontab:

```bash
crontab -e
```

Add (daily at 3 AM):

```
0 3 * * * /Users/<you>/github/gardenkit/scripts/gardener-run.sh
```

Verify it's installed:

```bash
crontab -l | grep gardener
```

### Cadences worth considering

- **Daily, 3 AM**: full pass. Good default.
- **Hourly**: inbox processing only. Add a second entry that calls a lighter variant if you capture a lot during the day.
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

**`claude: command not found` in log:** the cron PATH isn't picking up Claude. Edit `gardener-run.sh` to source the right profile, or set PATH explicitly at the top.

**`git push failed`:** the cron user can't auth to GitHub. Make sure your SSH key works headlessly (`ssh -T git@github.com` from a fresh shell), or use a credential helper.

**Gardener never commits anything:** check the log. The gardener is conservative: if there's nothing in `inbox/` and no link/dedupe work to do, it'll exit cleanly with no changes.
