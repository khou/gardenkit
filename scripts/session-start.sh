#!/usr/bin/env bash
# SessionStart hook for the garden vault.
# Pulls latest from git (silent on failure), then prints index + user identity.
#
# Output format auto-detects the caller:
#   - Cursor (CURSOR_VERSION env var set): JSON {"additional_context": "..."}
#   - Claude Code (default): plain text to stdout
#
# Override with --json or --text as $1 if auto-detection picks wrong.

set -e

VAULT="${GARDEN_VAULT:-$HOME/garden}"
# Auto-detect output mode: Cursor sets $CURSOR_VERSION on every hook
# invocation; Claude Code does not. Explicit flag wins if passed.
if [ -n "${CURSOR_VERSION:-}" ]; then
  MODE="${1:---json}"
else
  MODE="${1:---text}"
fi

# Pull latest if remote configured. Don't fail the hook if remote is missing.
if [ -d "$VAULT/.git" ]; then
  cd "$VAULT"
  if git remote get-url origin >/dev/null 2>&1; then
    git pull --quiet --rebase 2>/dev/null || true
  fi
fi

# Build the context body. Keep small.this goes into every session.
BODY=$(cat <<EOF
<garden-vault>

## ~/garden/00-index.md

$(cat "$VAULT/00-index.md" 2>/dev/null || echo "(missing)")

## ~/garden/meta/user.md

$(cat "$VAULT/meta/user.md" 2>/dev/null || echo "(missing)")

## ~/garden/meta/soul.md

$(cat "$VAULT/meta/soul.md" 2>/dev/null || echo "(missing)")

</garden-vault>
EOF
)

case "$MODE" in
  --json)
    # Cursor expects a JSON object on stdout. additional_context is injected
    # into the session's initial system context.
    if command -v python3 >/dev/null 2>&1; then
      printf '%s' "$BODY" | python3 -c "import sys, json; print(json.dumps({'additional_context': sys.stdin.read()}))"
    else
      # Fallback: very basic escape. Most macOS/Linux ship python3, but cover
      # the edge case so cron doesn't fail silently.
      ESCAPED=$(printf '%s' "$BODY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
      printf '{"additional_context": "%s"}\n' "$ESCAPED"
    fi
    ;;
  --text|*)
    printf '%s\n' "$BODY"
    ;;
esac
