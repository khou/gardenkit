# Scheduling the gardener

The gardener is an LLM agent. Cron/routine just triggers it.

## Option A: Routine (cloud)

**Use when:** you want it to run whether or not your laptop is on.

**Requires:** vault pushed to GitHub, GitHub plugin connected to Cowork/Claude.

Use the `schedule` skill in Claude Code to create a routine:

```
/schedule
```

When prompted, define a daily routine that:
1. Clones/pulls `<your-username>/brain`
2. Reads `meta/gardener-rules.md`
3. Invokes `brain-gardener` skill logic
4. Commits with `gardener:` prefix and pushes

Suggested cadences:
- **Hourly:** process inbox only (cheap, fast)
- **Daily:** full pass (link maintenance, dedupe, MOC update)
- **Weekly:** review synthesis
- **Monthly:** decay old dailies into a summary

## Option B: Local cron

**Use when:** you don't need it running while traveling, or you have local-only resources to scan.

Crontab entry — daily at 3 AM:

```
0 3 * * * /Users/<you>/github/brain-os/scripts/gardener-run.sh
```

`gardener-run.sh` invokes `claude -p` headlessly with a focused prompt that triggers the `brain-gardener` skill, then commits/pushes the vault.

## Option C: Both

Daily routine for the always-on baseline; local cron for anything that needs your machine (e.g., importing a watched folder, integrating a local-only tool).

## Cost note

Routines are billed agent runs. For hourly cadences this is fine. For sub-hour, prefer local cron.

## Verifying the gardener ran

Each gardener pass leaves a commit with `gardener: <date> — <summary>` in the vault git log. Check periodically:

```bash
cd ~/brain && git log --grep '^gardener:' --oneline | head
```
