#!/usr/bin/env bash
# Headless gardener invocation for cron or routine.
# Runs Claude in -p mode with a focused prompt that triggers the brain-gardener skill.

set -e

VAULT="${BRAIN_VAULT:-$HOME/brain}"
DATE=$(date +%Y-%m-%d)

cd "$VAULT"

# Pull latest before gardening
if git remote get-url origin >/dev/null 2>&1; then
  git pull --quiet --rebase 2>/dev/null || {
    echo "$(date): gardener-run: git pull failed, skipping" >&2
    exit 1
  }
fi

# Invoke gardener skill via headless Claude
claude -p "Run the brain-gardener skill on the vault at $VAULT. Today is $DATE. Process inbox, maintain links, dedupe, update MOCs, and commit + push. Be thorough but conservative — when in doubt, leave a NOTE blockquote rather than guessing." 2>&1 | tee -a "$VAULT/.gardener-log"

# If gardener changed anything and didn't push, push now
cd "$VAULT"
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "gardener: $DATE — auto-commit (skill did not commit)" -q
fi
if git remote get-url origin >/dev/null 2>&1; then
  git push --quiet 2>/dev/null || echo "$(date): gardener-run: git push failed" >&2
fi
