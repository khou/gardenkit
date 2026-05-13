# Scheduling the gardener

The gardener is one LLM agent that runs through all phases each pass: file inbox captures, link, dedupe, summarize, commit, push. The scheduler just triggers it.

Three paths, in order of preference:

1. **[Local routine](#default-claude-code-desktop-local-routine)** (Claude Code Desktop) — *default*. Free with your subscription. Lowest friction.
2. **[Cron + API key](#fallback-cron--anthropic_api_key)** — for Cursor-only users, or Claude users who don't want Desktop pinned open. **Billed separately** from your subscription.
3. **[Cloud routine](#always-on-cloud-routine)** — for laptops that travel and can't be relied on to be awake. Also billed separately.

The shared task prompt for all three paths lives in [`templates/scheduled-task-gardener.md`](../templates/scheduled-task-gardener.md). `__GARDENKIT_DIR__` is substituted with this repo's absolute path.

## Default: Claude Code Desktop local routine

A scheduled task inside [Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks). Runs as a fresh Claude Code session every 4 hours, using your subscription auth, with full local file access and your configured MCPs.

### Why this is the default

- **No new auth.** Uses the Desktop app's existing OAuth session. The macOS Keychain problem that breaks cron-based gardening (see [fallback section](#fallback-cron--anthropic_api_key)) doesn't apply because the task runs *inside* the GUI app, not via a daemon.
- **No extra billing.** Runs against your Claude Code Pro/Max seat, same as interactive use.
- **Catches up on wake.** If your laptop was asleep through a scheduled tick, Desktop fires exactly one catch-up run for the most recently missed time on the next wake.

### Prerequisites

Claude Code Desktop installed. Download from [code.claude.com/docs/en/desktop-quickstart](https://code.claude.com/docs/en/desktop-quickstart). Open the **Code** tab once and sign in with the same account that has your Pro/Max plan.

### Setup

In any Claude Code Desktop session, ask Claude:

> Set up the gardener as a scheduled task that runs every 4 hours. Use the prompt template at `<gardenkit-repo>/templates/scheduled-task-gardener.md` and substitute `__GARDENKIT_DIR__` with the gardenkit repo path.

Claude calls `mcp__scheduled-tasks__create_scheduled_task` with `cronExpression: "7 */4 * * *"`. You'll see an approval dialog — accept it. The task is stored at `~/.claude/scheduled-tasks/gardener/SKILL.md`.

`install.sh` walks you through this in section 6 if you run it interactively.

### First-run permission priming

The gardener reads + writes inside `~/garden/` and does a `git push`. By default each tool surface prompts the first time. To unattend future runs:

1. Open Desktop **Routines** → click the **gardener** task.
2. Click **Run now**.
3. Watch the running session in the sidebar. As permission prompts appear (file edits, git push), click **always allow** for each.
4. Wait for the run to finish. Subsequent runs auto-approve the same tools.

You can review and revoke approvals later from the task's **Always allowed** panel.

### Caveats

- **Desktop must be running.** If the app is closed when a task is due, it runs on next launch (one catch-up, not one per missed slot).
- **Don't enable "Keep computer awake"** unless you want the laptop to never idle-sleep on your account. The default behavior — skip on sleep, catch up on wake — is fine for vault maintenance.

## Fallback: cron + ANTHROPIC_API_KEY

For Cursor-only users, or Claude users who don't want the Desktop app pinned open. Cron triggers `scripts/gardener-run.sh`, which invokes `claude -p` headlessly.

### Cost warning

Setting `ANTHROPIC_API_KEY` in your shell makes Claude Code use the **API account**, not your Pro/Max subscription. **Subscriptions do not include API credits.** A 6×/day gardener that does real filing/dedup work — depending on vault size — can run real money over a month. See [Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan).

If billing matters and you have Claude Code Desktop available, use the [local routine path](#default-claude-code-desktop-local-routine) instead.

### Why the API key is required

On macOS, cron runs in a launchd daemon context that **cannot reach the login keychain** where `claude /login` stores OAuth tokens. The Claude CLI will silently fail with `Not logged in` on every cron tick. `gardener-run.sh` fails fast (and notifies via `osascript` or `$GARDENER_FAILURE_HOOK`) if `ANTHROPIC_API_KEY` is unset, so you won't lose a week of runs to silent auth failure.

### Setup

1. Get an API key from [console.anthropic.com](https://console.anthropic.com/) and fund the account. Add to your shell profile:
   ```bash
   # ~/.zshrc (or ~/.bashrc, etc.)
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```
   Open a fresh terminal so the export propagates.

2. Install the cron entry (every 4 hours, off-minute to stagger):
   ```bash
   ( crontab -l 2>/dev/null; echo "7 */4 * * * /Users/<you>/github/gardenkit/scripts/gardener-run.sh" ) | crontab -
   ```

3. Verify:
   ```bash
   crontab -l | grep gardener
   ```

### Trust model

`gardener-run.sh` invokes `claude -p --dangerously-skip-permissions` unconditionally on this path. The cron context has no TTY to approve prompts, so it has to run fully autonomous or not at all.

The gardener writes only to `~/garden/` and its git remote — it doesn't reach out to external services. If your global `~/.claude/settings.json` configures MCPs with high-stakes write tools, those would still be reachable in principle by a misbehaving cron-spawned Claude; consider scoping them to read-only at the MCP layer or moving them out of global settings so cron-spawned Claude can't see them.

### Caveats

- Your laptop must be awake/on for cron to fire. If it sleeps through 03:07, the run is skipped (no catch-up, unlike the Desktop path).
- Cron has a minimal PATH. `gardener-run.sh` sources `~/.zshrc` to find `claude`. If you're on bash, edit the script.
- macOS may require granting cron Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`.

## Always-on: cloud routine

If your laptop is regularly off for days at a time, use an [Anthropic-hosted routine](https://code.claude.com/docs/en/routines). Same `mcp__scheduled-tasks__create_scheduled_task` MCP, but the task runs on Anthropic's cloud.

Like the cron path, **this is billed per agent run**, separate from your Claude Code subscription. The trade is that your laptop doesn't have to be awake.

Caveats specific to cloud routines:

- The routine clones your vault on each run, so `~/garden` must live on a git remote it can reach.

The cloud path is reasonable if you've already accepted those trade-offs. Otherwise prefer the local routine.

## Verifying the gardener ran

Each pass writes a `gardener:` commit to the vault:

```bash
cd ~/garden && git log --grep '^gardener:' --oneline | head
```

For the cron-fallback path, also check the log file:

```bash
tail ~/garden/.gardener-log
```

The local-routine path doesn't write to `.gardener-log`; check Desktop **Routines** → **gardener** → run history instead.

## Troubleshooting

**`Not logged in · Please run /login` in `.gardener-log`:** you're on the cron path with no API key. Either set `ANTHROPIC_API_KEY` (and accept API-account billing) or switch to the local-routine path. `claude /login` from a terminal **will not help** — the OAuth token it stores in macOS Keychain is unreachable from cron.

**`ANTHROPIC_API_KEY unset` in `.gardener-log`:** same as above. The script now fails fast with this exact message instead of silently retrying for a week.

**`Credit balance is too low` in `.gardener-log`:** API account has no funds. Top up at [console.anthropic.com](https://console.anthropic.com/) or move to the local-routine path.

**`claude: command not found` in `.gardener-log`:** cron PATH isn't picking up Claude. Edit `gardener-run.sh` to source the right profile, or set PATH explicitly at the top.

**`git push failed`:** the cron user can't auth to GitHub. Make sure your SSH key works headlessly (`ssh -T git@github.com` from a fresh shell), or use a credential helper.

**Gardener never commits anything:** the gardener is conservative. If `inbox/` is empty and there's no link/dedupe work to do, it exits cleanly with no changes.

**Log file never gets created at all (no `~/garden/.gardener-log`) on cron path:** cron isn't reaching the script's first log write. Most likely macOS Full Disk Access: System Settings → Privacy & Security → Full Disk Access → add `/usr/sbin/cron`. Verify cron itself is firing with `log show --predicate 'process == "cron"' --last 1h | grep gardener`.

**Desktop local-routine task stalls partway through a run:** a permission prompt the task doesn't have "always allow" for. Open the running session in the sidebar, approve the prompt, and select "always allow" so the next run doesn't stall on the same tool.
