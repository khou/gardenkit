#!/usr/bin/env bash
# SessionStart hook for the garden vault.
# Pulls latest from git (silent on failure), then prints index + user identity to stdout.
# Stdout becomes additionalContext injected into the new session.

set -e

VAULT="$HOME/garden"

# Pull latest if remote configured. Don't fail the hook if remote is missing.
if [ -d "$VAULT/.git" ]; then
  cd "$VAULT"
  if git remote get-url origin >/dev/null 2>&1; then
    git pull --quiet --rebase 2>/dev/null || true
  fi
fi

# Emit index and identity. Keep small — this goes into every session.
echo "<garden-vault>"
echo ""
echo "## ~/garden/00-index.md"
echo ""
cat "$VAULT/00-index.md" 2>/dev/null || echo "(missing)"
echo ""
echo "## ~/garden/meta/user.md"
echo ""
cat "$VAULT/meta/user.md" 2>/dev/null || echo "(missing)"
echo ""
echo "## ~/garden/meta/soul.md"
echo ""
cat "$VAULT/meta/soul.md" 2>/dev/null || echo "(missing)"
echo ""
echo "</garden-vault>"
