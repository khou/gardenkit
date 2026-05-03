#!/usr/bin/env bash
# Headless gardener invocation for cron.
# Runs Claude in -p mode with a focused prompt that triggers the gardener skill.
#
# Cron has a minimal PATH; we source the user's shell profile so `claude` resolves.
# If you're not on zsh, change the source line accordingly.

set -e

# Source shell profile so `claude` is on PATH under cron
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" 2>/dev/null || true

VAULT="${GARDEN_VAULT:-$HOME/garden}"
DATE=$(date +%Y-%m-%d)
LOG="$VAULT/.gardener-log"

# Sanity check
if ! command -v claude >/dev/null 2>&1; then
  echo "$(date): gardener-run: 'claude' CLI not found on PATH" >&2
  exit 1
fi
if [ ! -d "$VAULT" ]; then
  echo "$(date): gardener-run: vault $VAULT does not exist" >&2
  exit 1
fi

cd "$VAULT"

# Pull latest before gardening (skip if no remote)
if git remote get-url origin >/dev/null 2>&1; then
  git pull --quiet --rebase 2>/dev/null || {
    echo "$(date): gardener-run: git pull failed, aborting" >> "$LOG"
    exit 1
  }
fi

# Invoke gardener skill via headless Claude
echo "=== gardener run $DATE ===" >> "$LOG"
claude -p "Run the gardener skill on the vault at $VAULT. Today is $DATE. Process inbox, maintain links, dedupe, update MOCs, and commit + push. Be thorough but conservative — when in doubt, leave a NOTE blockquote rather than guessing." >> "$LOG" 2>&1

# Belt-and-braces: if anything is unstaged, commit it
cd "$VAULT"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE — auto-commit (uncommitted residue)" -q
fi

# Push if remote configured
if git remote get-url origin >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || echo "$(date): gardener-run: git push failed" >> "$LOG"
fi
