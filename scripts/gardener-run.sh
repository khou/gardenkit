#!/usr/bin/env bash
# Fallback cron runner for the gardener.
#
# The default scheduling path is a Claude Code Desktop local routine (free with
# subscription, no keychain issues). This script is the cron-based fallback for:
#   - Cursor-only users with no Claude Code Desktop, OR
#   - users who don't want to keep Desktop pinned open.
#
# It requires ANTHROPIC_API_KEY because the macOS Keychain (where `claude /login`
# stores OAuth tokens) is not reachable from cron's launchd daemon context. The
# API key bills against your API account, which is SEPARATE from your Claude
# Code Pro/Max subscription -- the subscription does NOT include API credits.
#
# Cron has a minimal PATH; we source the user's shell profile so `claude`
# resolves. If you're not on zsh, change the source lines accordingly.

# Source shell profile so `claude` is on PATH under cron.
# Do this BEFORE `set -e`: under set -e, a single failing command inside the
# sourced rc kills the whole script even with `|| true` on the source line.
set +e
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" 2>/dev/null
set -e

VAULT="${GARDEN_VAULT:-$HOME/garden}"
DATE=$(date +%Y-%m-%d)
LOG="$VAULT/.gardener-log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPT_TEMPLATE="$REPO_DIR/templates/scheduled-task-gardener.md"

# Log helper: write to log if vault exists, else stderr (cron will mail it).
log() { if [ -d "$VAULT" ]; then echo "$(date): $*" >> "$LOG"; else echo "$(date): $*" >&2; fi; }

# Failure notifier: surfaces silent failures (auth, crash) so a cron-headless
# gardener doesn't fail silently for days. macOS uses osascript banners; on
# other platforms it logs to stderr (cron mails to $MAILTO if configured).
# A user-supplied $GARDENER_FAILURE_HOOK script is invoked with the reason as
# $1 if present, for custom routing (Slack webhook, ntfy, etc.).
notify_failure() {
  local reason="$1"
  log "FAILURE: $reason"
  if [ -n "${GARDENER_FAILURE_HOOK:-}" ] && [ -x "$GARDENER_FAILURE_HOOK" ]; then
    "$GARDENER_FAILURE_HOOK" "$reason" 2>/dev/null || true
  elif command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$reason. See $LOG\" with title \"Gardener failed\"" 2>/dev/null || true
  else
    echo "gardener-run FAILURE: $reason (see $LOG)" >&2
  fi
}

# Sanity checks
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  log "ANTHROPIC_API_KEY is unset. Cron-based gardening requires an API key because"
  log "the macOS Keychain (where claude /login stores OAuth) is not reachable from cron."
  log "Either export ANTHROPIC_API_KEY in your shell profile, or switch to a Claude"
  log "Code Desktop local routine (free with subscription). See docs/SCHEDULING.md."
  notify_failure "ANTHROPIC_API_KEY unset"
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  log "gardener-run: 'claude' CLI not found on PATH (PATH=$PATH)"
  exit 1
fi
if [ ! -d "$VAULT" ]; then
  echo "$(date): gardener-run: vault $VAULT does not exist" >&2
  exit 1
fi
if [ ! -f "$PROMPT_TEMPLATE" ]; then
  log "gardener-run: prompt template missing at $PROMPT_TEMPLATE"
  exit 1
fi

cd "$VAULT"

# If the vault has uncommitted residue from a prior interrupted run or manual
# edit, commit it first so `git pull --rebase` doesn't bail.
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE.pre-pull-residue" -q || true
fi

# Pull latest before gardening (skip if no remote)
if git remote get-url origin >/dev/null 2>&1; then
  git pull --quiet --rebase 2>>"$LOG" || {
    notify_failure "git pull --rebase failed"
    exit 1
  }
fi

# Build the prompt: read the shared template, substitute the gardenkit absolute
# path. Same template the Claude Code Desktop local-routine path uses, so both
# scheduling paths run the same prompt body.
PROMPT=$(sed "s|__GARDENKIT_DIR__|$REPO_DIR|g" "$PROMPT_TEMPLATE")

# Invoke Claude headlessly. Cron has no TTY, so --dangerously-skip-permissions
# is unconditional for this path -- if you opted into API-key-billed cron,
# you've already accepted full autonomy. The gardener skill's read-only-on-
# external-sources contract is the in-prompt guardrail; see docs/SCHEDULING.md
# for the trust model.
echo "=== gardener run $DATE ===" >> "$LOG"

# Capture output to a temp file so we can both log it and inspect it for failure
# markers. set +e because we want to handle the exit code ourselves.
CLAUDE_OUT=$(mktemp "${TMPDIR:-/tmp}/gardener-claude.XXXXXX")
set +e
claude -p --dangerously-skip-permissions "$PROMPT" > "$CLAUDE_OUT" 2>&1
CLAUDE_RC=$?
set -e
cat "$CLAUDE_OUT" >> "$LOG"

if [ $CLAUDE_RC -ne 0 ]; then
  notify_failure "claude -p exited $CLAUDE_RC"
elif grep -qE "Not logged in|Please run /login|Invalid API key|Authentication" "$CLAUDE_OUT"; then
  notify_failure "claude auth failed (check ANTHROPIC_API_KEY is valid and has API credits)"
fi
rm -f "$CLAUDE_OUT"

# Belt-and-braces: if anything is unstaged, commit it
cd "$VAULT"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE.auto-commit (uncommitted residue)" -q
fi

# Push if remote configured
if git remote get-url origin >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || notify_failure "git push failed"
fi
