#!/usr/bin/env bash
# gardenkit installer. Idempotent. Never overwrites user files.
#
# What it does:
#   1. Creates ~/garden/ vault from templates if missing
#   2. Symlinks skills/garden-* into ~/.claude/skills/
#   3. Wires SessionStart hook in ~/.claude/settings.json
#   4. Initializes git in ~/garden/ if not already
#
# Re-run safe. To uninstall, see ./uninstall.sh (or remove symlinks + hook manually).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${GARDEN_VAULT:-$HOME/garden}"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"

say() { printf "  %s\n" "$*"; }
section() { printf "\n== %s ==\n" "$*"; }

section "1. Vault at $VAULT"
if [ -d "$VAULT" ]; then
  say "exists, skipping seed"
else
  mkdir -p "$VAULT"/{notes,projects,people,daily,decisions,inbox,learnings,meta}
  cp -n "$REPO_DIR/templates/00-index.md" "$VAULT/00-index.md"
  cp -n "$REPO_DIR/templates/README.md" "$VAULT/README.md"
  cp -n "$REPO_DIR/templates/meta/user.md" "$VAULT/meta/user.md"
  cp -n "$REPO_DIR/templates/meta/soul.md" "$VAULT/meta/soul.md"
  cp -n "$REPO_DIR/templates/meta/gardener-rules.md" "$VAULT/meta/gardener-rules.md"
  cp -n "$REPO_DIR/templates/projects/EXAMPLE.md" "$VAULT/projects/EXAMPLE.md"
  say "seeded from templates"
fi

section "2. Git in vault"
if [ -d "$VAULT/.git" ]; then
  say "git already initialized"
else
  (cd "$VAULT" && git init -q && git add -A && git commit -q -m "Initial vault scaffold")
  say "git initialized + initial commit"
fi

section "3. Skills (symlinks into ~/.claude/skills/)"
mkdir -p "$SKILLS_DIR"
for skill in garden-capture garden-recall gardener; do
  src="$REPO_DIR/skills/$skill"
  dst="$SKILLS_DIR/$skill"
  if [ -L "$dst" ]; then
    say "$skill: symlink exists"
  elif [ -e "$dst" ]; then
    say "$skill: WARN — non-symlink exists at $dst, leaving alone (move it aside to install)"
  else
    ln -s "$src" "$dst"
    say "$skill: linked"
  fi
done

section "4. Hooks in $SETTINGS"
HOOK_START="$REPO_DIR/scripts/session-start.sh"
HOOK_END="$REPO_DIR/scripts/session-end.sh"
if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "$HOOK_START" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "$HOOK_END" }
        ]
      }
    ]
  }
}
EOF
  say "settings.json created with SessionStart + SessionEnd hooks"
else
  for h in "SessionStart:$HOOK_START" "SessionEnd:$HOOK_END"; do
    name="${h%%:*}"
    cmd="${h#*:}"
    if grep -q "$cmd" "$SETTINGS"; then
      say "$name hook already wired"
    else
      say "$name hook NOT in settings.json — add manually under .hooks.$name:"
      say "  { \"hooks\": [{ \"type\": \"command\", \"command\": \"$cmd\" }] }"
    fi
  done
fi

section "5. Make scripts executable"
chmod +x "$REPO_DIR/scripts/"*.sh
say "done"

section "Next steps"
say "1. Fill ~/garden/meta/user.md — ask Claude: 'Interview me for my user.md (15 questions).'"
say "2. Push the vault to a private GitHub repo:"
say "     cd ~/garden && git remote add origin git@github.com:<you>/garden.git && git push -u origin main"
say "3. Schedule the gardener — see $REPO_DIR/docs/SCHEDULING.md"
say ""
say "Restart Claude Code to activate the SessionStart hook."
