#!/usr/bin/env bash
# Headless gardener invocation for Codex.
# Runs Codex in exec mode with a focused prompt that triggers the gardener skill.
#
# Cron has a minimal PATH; we source the user's shell profiles so `codex`
# resolves under non-interactive shells.

set +e
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" 2>/dev/null
set -e

VAULT="${GARDEN_VAULT:-$HOME/garden}"
DATE=$(date +%Y-%m-%d)
LOG="$VAULT/.gardener-log"

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
    echo "gardener-run-codex FAILURE: $reason (see $LOG)" >&2
  fi
}

if ! command -v codex >/dev/null 2>&1; then
  log "gardener-run-codex: 'codex' CLI not found on PATH (PATH=$PATH)"
  exit 1
fi
if [ ! -d "$VAULT" ]; then
  echo "$(date): gardener-run-codex: vault $VAULT does not exist" >&2
  exit 1
fi

cd "$VAULT"

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE.pre-pull-residue" -q || true
fi

if git remote get-url origin >/dev/null 2>&1; then
  git pull --quiet --rebase 2>>"$LOG" || {
    notify_failure "git pull --rebase failed"
    exit 1
  }
fi

HEADLESS_FLAGS=(--full-auto)
if [ "${CODEX_GARDENER_FULL_ACCESS:-}" = "1" ]; then
  HEADLESS_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
fi

PROMPT="Run the gardener skill on the vault at $VAULT. Today is $DATE. Process inbox, maintain links, dedupe, update MOCs, and commit + push. Be thorough but conservative. When in doubt, leave a NOTE blockquote rather than guessing."

echo "=== codex gardener run $DATE ===" >> "$LOG"
# Capture output to a temp file so we can both log it and inspect for failure
# markers. Codex error strings differ from Claude Code's; cover the common
# auth and execution patterns plus any non-zero exit.
CODEX_OUT=$(mktemp "${TMPDIR:-/tmp}/gardener-codex.XXXXXX")
set +e
codex exec -C "$VAULT" "${HEADLESS_FLAGS[@]}" "$PROMPT" > "$CODEX_OUT" 2>&1
CODEX_RC=$?
set -e
cat "$CODEX_OUT" >> "$LOG"

if [ $CODEX_RC -ne 0 ]; then
  notify_failure "codex exec exited $CODEX_RC"
elif grep -qE "not logged in|authentication|auth failed|API key|sign in" "$CODEX_OUT"; then
  notify_failure "codex auth not reachable from cron"
fi
rm -f "$CODEX_OUT"

cd "$VAULT"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE.auto-commit (uncommitted residue)" -q
fi

if git remote get-url origin >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || notify_failure "git push failed"
fi
