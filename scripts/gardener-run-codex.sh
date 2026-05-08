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
    log "gardener-run-codex: git pull failed, aborting"
    exit 1
  }
fi

HEADLESS_FLAGS=(--full-auto)
if [ "${CODEX_GARDENER_FULL_ACCESS:-}" = "1" ]; then
  HEADLESS_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
fi

PROMPT="Run the gardener skill on the vault at $VAULT. Today is $DATE. Process inbox, maintain links, dedupe, update MOCs, and commit + push. Be thorough but conservative. When in doubt, leave a NOTE blockquote rather than guessing."

echo "=== codex gardener run $DATE ===" >> "$LOG"
codex exec -C "$VAULT" "${HEADLESS_FLAGS[@]}" "$PROMPT" >> "$LOG" 2>&1

cd "$VAULT"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE.auto-commit (uncommitted residue)" -q
fi

if git remote get-url origin >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || echo "$(date): gardener-run-codex: git push failed" >> "$LOG"
fi
