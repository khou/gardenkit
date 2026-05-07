#!/usr/bin/env bash
# gardenkit installer. Idempotent. Never overwrites user files.
#
# What it does:
#   1. Creates ~/garden/ vault from templates if missing (including meta/refresh-sources.md)
#   2. Initializes git in ~/garden/ if not already
#   3. Symlinks skills/garden-* and skills/gardener into ~/.claude/skills/
#   4. Wires SessionStart, SessionEnd, and PreCompact hooks in ~/.claude/settings.json
#   5. Makes scripts/*.sh executable
#   6. Optionally enables GARDENER_AUTO_APPROVE in ~/.zshrc for headless cron runs
#
# Re-run safe. To uninstall, remove the symlinks in ~/.claude/skills/ and the
# hook entries in ~/.claude/settings.json manually.

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
  say "exists, will top up any missing meta files"
else
  mkdir -p "$VAULT"/{notes,projects,people,daily,decisions,inbox,learnings,meta}
  cp -n "$REPO_DIR/templates/00-index.md" "$VAULT/00-index.md"
  cp -n "$REPO_DIR/templates/README.md" "$VAULT/README.md"
  cp -n "$REPO_DIR/templates/projects/EXAMPLE.md" "$VAULT/projects/EXAMPLE.md"
  say "seeded from templates"
fi
# Top up meta files. cp -n is no-clobber: existing user edits stay.
mkdir -p "$VAULT/meta"
cp -n "$REPO_DIR/templates/meta/user.md" "$VAULT/meta/user.md"
cp -n "$REPO_DIR/templates/meta/soul.md" "$VAULT/meta/soul.md"
cp -n "$REPO_DIR/templates/meta/gardener-rules.md" "$VAULT/meta/gardener-rules.md"
cp -n "$REPO_DIR/templates/meta/derived-taxonomies.md" "$VAULT/meta/derived-taxonomies.md"
cp -n "$REPO_DIR/templates/meta/migration-state.md" "$VAULT/meta/migration-state.md"
cp -n "$REPO_DIR/templates/meta/refresh-sources.md" "$VAULT/meta/refresh-sources.md"

# If meta files differ from templates, the gardener will reconcile content
# drift on its next run; this just surfaces that drift exists.
if ! diff -rq "$REPO_DIR/templates/meta/" "$VAULT/meta/" >/dev/null 2>&1; then
  say "meta files differ from templates; gardener will reconcile on next run."
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
for src in "$REPO_DIR"/skills/garden-* "$REPO_DIR"/skills/gardener; do
  [ -d "$src" ] || continue
  skill=$(basename "$src")
  dst="$SKILLS_DIR/$skill"
  if [ -L "$dst" ]; then
    say "$skill: symlink exists"
  elif [ -e "$dst" ]; then
    say "$skill: WARN, non-symlink exists at $dst, leaving alone (move it aside to install)"
  else
    ln -s "$src" "$dst"
    say "$skill: linked"
  fi
done

section "4. Hooks in $SETTINGS"
HOOK_START="$REPO_DIR/scripts/session-start.sh"
HOOK_END="$REPO_DIR/scripts/extract-to-inbox.sh session"
HOOK_COMPACT="$REPO_DIR/scripts/extract-to-inbox.sh pre-compact"
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
    ],
    "PreCompact": [
      {
        "hooks": [
          { "type": "command", "command": "$HOOK_COMPACT" }
        ]
      }
    ]
  }
}
EOF
  say "settings.json created with SessionStart + SessionEnd + PreCompact hooks"
else
  for h in "SessionStart:$HOOK_START" "SessionEnd:$HOOK_END" "PreCompact:$HOOK_COMPACT"; do
    name="${h%%:*}"
    cmd="${h#*:}"
    if grep -qF "$cmd" "$SETTINGS"; then
      say "$name hook already wired"
    else
      say "$name hook NOT in settings.json. Add manually under .hooks.$name:"
      say "  { \"hooks\": [{ \"type\": \"command\", \"command\": \"$cmd\" }] }"
    fi
  done
fi

section "5. Make scripts executable"
chmod +x "$REPO_DIR/scripts/"*.sh
say "done"

section "6. Headless permissions for the cron-driven gardener"
say "The gardener runs in cron with no TTY. To do its work without blocking on"
say "permission prompts, it needs --dangerously-skip-permissions, which gives"
say "Claude autonomous tool access for the run."
say ""
say "The skill contract says the gardener is read-only on external sources:"
say "  - writes/commits/pushes inside ~/garden only"
say "  - reads from connected MCPs (Gmail, Drive, Slack, etc.)"
say "  - never sends email, posts Slack, modifies Drive files, etc."
say ""
say "But contract /= enforcement. --dangerously-skip-permissions still gives"
say "Claude the technical capability to call write tools on connected MCPs."
say "The contract is a soft constraint a prompt-injection in pulled content"
say "could try to bypass. If your global MCPs include high-stakes write"
say "tools, consider scoping them to read-only at the MCP layer or moving"
say "them out of global ~/.claude/settings.json so cron can't see them."
say ""
say "Without GARDENER_AUTO_APPROVE: each cron run plans changes but stops"
say "at the first permission prompt. With it: runs execute unattended."
say ""
ZSHRC="$HOME/.zshrc"
if grep -q "GARDENER_AUTO_APPROVE" "$ZSHRC" 2>/dev/null; then
  say "Already enabled (GARDENER_AUTO_APPROVE found in ~/.zshrc). Skipping."
else
  printf "  Enable autonomous mode for cron runs? [y/N] "
  read -r AUTO_APPROVE_ANS </dev/tty || AUTO_APPROVE_ANS=""
  if [[ "$AUTO_APPROVE_ANS" =~ ^[Yy] ]]; then
    {
      echo ""
      echo "# gardenkit: auto-approve cron-driven gardener runs"
      echo "export GARDENER_AUTO_APPROVE=1"
    } >> "$ZSHRC"
    say "Added export GARDENER_AUTO_APPROVE=1 to ~/.zshrc."
    say "Run 'source ~/.zshrc' or open a new terminal so cron picks it up."
  else
    say "Skipped. To enable later, add this to ~/.zshrc:"
    say "    export GARDENER_AUTO_APPROVE=1"
  fi
fi

section "Next steps"
say "1. Fill ~/garden/meta/user.md. Ask Claude: 'Interview me for my user.md (15 questions).'"
say "2. Bootstrap your voice profile. Ask Claude: 'init my voice from Slack' (invokes garden-voice)."
say "3. Bootstrap your knowledge graph. Ask Claude: 'init my garden from connected sources' (invokes garden-bootstrap)."
say "4. Push the vault to a private GitHub repo:"
say "     cd ~/garden && git remote add origin git@github.com:<you>/garden.git && git push -u origin main"
say "5. Log in to Claude headlessly so cron-spawned 'claude -p' has tokens:"
say "     claude /login"
say "   (If you have ANTHROPIC_API_KEY exported, unset it first; env-var auth overrides your subscription.)"
say "6. Schedule the gardener. See $REPO_DIR/docs/SCHEDULING.md"
say ""
say "Restart Claude Code to activate the SessionStart hook."
