#!/usr/bin/env bash
# gardenkit installer. Idempotent. Never overwrites user files.
#
# What it does:
#   1. Creates ~/garden/ vault from templates if missing
#   2. Initializes git in ~/garden/ if not already
#   3. Symlinks skills/garden-* and skills/gardener into ~/.claude/skills/,
#      plus a Cursor-compatible mirror into $VAULT/.cursor/rules/ as .mdc rules
#   4. Wires the SessionStart hook in ~/.claude/settings.json AND a
#      sessionStart hook in ~/.cursor/hooks.json (user-global). Both point
#      at scripts/session-start.sh, which auto-detects Cursor via
#      $CURSOR_VERSION and emits JSON when it sees it.
#      No session-end / pre-compact hook is wired -- capture is explicit-only
#      via the garden-capture skill.
#   5. Makes scripts/*.sh executable
#   6. Prints the per-agent scheduling instructions for the gardener
#
# Re-run safe. To uninstall, remove the symlinks in ~/.claude/skills/
# and $VAULT/.cursor/rules/, plus the hook entries in ~/.claude/settings.json
# and ~/.cursor/hooks.json manually.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT="${GARDEN_VAULT:-$HOME/garden}"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CURSOR_DIR="$HOME/.cursor"
CURSOR_RULES_DIR="$VAULT/.cursor/rules"
CURSOR_HOOKS="$CURSOR_DIR/hooks.json"
SETTINGS="$CLAUDE_DIR/settings.json"

say() { printf "  %s\n" "$*"; }
section() { printf "\n== %s ==\n" "$*"; }

# cp_if_missing copies $1 to $2 only if $2 does not already exist. macOS BSD
# `cp -n` returns exit code 1 when the destination exists, which combined with
# `set -e` killed the installer on every re-run.
cp_if_missing() {
  [ -e "$2" ] || cp "$1" "$2"
}

section "1. Vault at $VAULT"
if [ -d "$VAULT" ]; then
  say "exists, will top up any missing meta files"
else
  mkdir -p "$VAULT"/{notes,projects,people,daily,decisions,inbox,learnings,meta}
  cp_if_missing "$REPO_DIR/templates/00-index.md" "$VAULT/00-index.md"
  cp_if_missing "$REPO_DIR/templates/README.md" "$VAULT/README.md"
  cp_if_missing "$REPO_DIR/templates/projects/EXAMPLE.md" "$VAULT/projects/EXAMPLE.md"
  say "seeded from templates"
fi
# Top up meta files. cp_if_missing preserves existing user edits.
mkdir -p "$VAULT/meta"
cp_if_missing "$REPO_DIR/templates/meta/user.md" "$VAULT/meta/user.md"
cp_if_missing "$REPO_DIR/templates/meta/soul.md" "$VAULT/meta/soul.md"
cp_if_missing "$REPO_DIR/templates/meta/gardener-rules.md" "$VAULT/meta/gardener-rules.md"
cp_if_missing "$REPO_DIR/templates/meta/derived-taxonomies.md" "$VAULT/meta/derived-taxonomies.md"
cp_if_missing "$REPO_DIR/templates/meta/migration-state.md" "$VAULT/meta/migration-state.md"

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

link_skills() {
  label="$1"
  skills_dir="$2"

  say "$label -> $skills_dir"
  mkdir -p "$skills_dir"
  for src in "$REPO_DIR"/skills/garden-* "$REPO_DIR"/skills/gardener; do
    [ -d "$src" ] || continue
    skill=$(basename "$src")
    dst="$skills_dir/$skill"
    if [ -L "$dst" ]; then
      say "  $skill: symlink exists"
    elif [ -e "$dst" ]; then
      say "  $skill: WARN, non-symlink exists at $dst, leaving alone (move it aside to install)"
    else
      ln -s "$src" "$dst"
      say "  $skill: linked"
    fi
  done
}

link_cursor_rules() {
  rules_dir="$1"

  say "Cursor -> $rules_dir"
  mkdir -p "$rules_dir"
  for src in "$REPO_DIR"/skills/garden-* "$REPO_DIR"/skills/gardener; do
    [ -d "$src" ] || continue
    skill=$(basename "$src")
    skill_md="$src/SKILL.md"
    [ -f "$skill_md" ] || continue
    dst="$rules_dir/$skill.mdc"
    if [ -L "$dst" ]; then
      say "  $skill.mdc: symlink exists"
    elif [ -e "$dst" ]; then
      say "  $skill.mdc: WARN, non-symlink exists at $dst, leaving alone (move it aside to install)"
    else
      ln -s "$skill_md" "$dst"
      say "  $skill.mdc: linked"
    fi
  done
}

section "3. Skills (symlinks into Claude skill dir; Cursor rules in vault)"
link_skills "Claude" "$CLAUDE_SKILLS_DIR"
link_cursor_rules "$CURSOR_RULES_DIR"

section "4. Hooks"
say "Wiring SessionStart in $SETTINGS (Claude)."
say "Wiring sessionStart in $CURSOR_HOOKS (Cursor, user-global)."
say "Only sessionStart is wired -- capture is explicit-only via the garden-capture skill."
HOOK_START="$REPO_DIR/scripts/session-start.sh"
# Cursor uses the same script; it auto-detects Cursor via $CURSOR_VERSION env
# var (set by Cursor on every hook invocation) and emits JSON instead of
# plain text. No flag needed -- Cursor doesn't reliably word-split the
# command field into argv.
CURSOR_HOOK_START="$HOOK_START"

# --- Claude ---
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
    ]
  }
}
EOF
  say "Claude settings.json created with SessionStart hook"
else
  if grep -qF "$HOOK_START" "$SETTINGS"; then
    say "Claude SessionStart hook already wired"
  else
    say "Claude SessionStart hook NOT in settings.json. Add manually under .hooks.SessionStart:"
    say "  { \"matcher\": \"startup|resume\", \"hooks\": [{ \"type\": \"command\", \"command\": \"$HOOK_START\" }] }"
  fi
  # Legacy hooks from earlier installs: extract-to-inbox.sh wired as a
  # SessionEnd / PreCompact hook. The script no longer ships and capture
  # is explicit-only; warn so the user can clean up.
  if grep -qF "extract-to-inbox.sh" "$SETTINGS"; then
    say ""
    say "WARN: settings.json still references extract-to-inbox.sh as a hook."
    say "      The auto-capture extractor has been removed; gardenkit captures only"
    say "      via explicit garden-capture invocations now. Remove the SessionEnd"
    say "      and PreCompact blocks from settings.json."
  fi
fi

# --- Cursor ---
# Cursor hooks live at ~/.cursor/hooks.json (user-global), and event names are
# lowerCamelCase. Same three lifecycle events Claude has.
mkdir -p "$CURSOR_DIR"
if [ ! -f "$CURSOR_HOOKS" ]; then
  cat > "$CURSOR_HOOKS" <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "type": "command", "command": "$CURSOR_HOOK_START", "timeout": 10 }
    ]
  }
}
EOF
  say "Cursor hooks.json created with sessionStart hook"
else
  if grep -qF "$CURSOR_HOOK_START" "$CURSOR_HOOKS"; then
    say "Cursor sessionStart hook already wired"
  else
    say "Cursor sessionStart hook NOT in $CURSOR_HOOKS. Add manually under .hooks.sessionStart:"
    say "  { \"type\": \"command\", \"command\": \"$CURSOR_HOOK_START\" }"
  fi
  # Legacy hook from earlier installs (see Claude block above).
  if grep -qF "extract-to-inbox.sh" "$CURSOR_HOOKS"; then
    say ""
    say "WARN: $CURSOR_HOOKS still references extract-to-inbox.sh as a hook."
    say "      The auto-capture extractor has been removed; gardenkit captures only"
    say "      via explicit garden-capture invocations now. Remove the sessionEnd"
    say "      and preCompact blocks from $CURSOR_HOOKS."
  fi
fi

section "5. Make scripts executable"
chmod +x "$REPO_DIR/scripts/"*.sh
say "done"

section "6. Schedule the gardener"
say "The gardener needs to run on a schedule to maintain the vault. Two paths,"
say "and which one fits depends on which coding agent you use."
say ""
say "  [c] Claude Code Desktop local routine  (default; free with subscription)"
say "      - Runs every 4 hours in a Claude Code Desktop scheduled task."
say "      - Auth via your Pro/Max subscription. No API key needed."
say "      - Requires the Desktop app to be running; skips if asleep, one"
say "        catch-up on wake."
say "      - The agent that ran install.sh provisions it via the"
say "        scheduled-tasks MCP. You'll get an approval dialog."
say ""
say "  [u] Cursor (or Claude users who don't want Desktop pinned open)"
say "      - Cron entry + ANTHROPIC_API_KEY in your shell profile."
say "      - Auth via the API key. NOTE: API keys bill against your API"
say "        account, which is SEPARATE from Claude Pro/Max -- the"
say "        subscription does NOT include API credits."
say "      - Reason: macOS keychain (where 'claude /login' stores OAuth)"
say "        is not reachable from cron's launchd daemon context."
say ""
SCHEDULING_CHOICE=""
if [ -t 0 ]; then
  printf "  Which path? [c]laude / c[u]rsor / [s]kip: "
  read -r SCHEDULING_CHOICE || SCHEDULING_CHOICE=""
elif [ -t 1 ] && [ -r /dev/tty ]; then
  # stdin is a pipe (agent running install.sh) but stdout is a terminal
  # and /dev/tty is readable -- attempt a controlling-tty read.
  printf "  Which path? [c]laude / c[u]rsor / [s]kip: "
  { read -r SCHEDULING_CHOICE; } </dev/tty 2>/dev/null || SCHEDULING_CHOICE=""
fi
SCHEDULING_CHOICE=$(printf '%s' "$SCHEDULING_CHOICE" | tr '[:upper:]' '[:lower:]')
case "$SCHEDULING_CHOICE" in
  c|claude)
    say ""
    say "  --> Claude routine path selected."
    say ""
    say "  NEXT: in your Claude Code Desktop session, ask Claude:"
    say ""
    say "      'Set up the gardener as a scheduled task that runs every"
    say "       4 hours. Use the prompt template at"
    say "       $REPO_DIR/templates/scheduled-task-gardener.md and substitute"
    say "       __GARDENKIT_DIR__ with $REPO_DIR.'"
    say ""
    say "  Claude will call mcp__scheduled-tasks__create_scheduled_task with"
    say "  cronExpression '7 */4 * * *'. You'll see an approval dialog --"
    say "  accept it. The task is stored at"
    say "  ~/.claude/scheduled-tasks/gardener/SKILL.md."
    say ""
    say "  First run: click 'Run now' in Desktop Routines, watch for permission"
    say "  prompts (Bash, git push, etc.), and select 'always allow' for each"
    say "  so future runs proceed unattended."
    ;;
  u|cursor)
    say ""
    say "  --> Cursor / cron-with-API-key path selected."
    say ""
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
      say "  ANTHROPIC_API_KEY is already set in this shell. Good."
    else
      say "  Set ANTHROPIC_API_KEY in your shell profile (~/.zshrc or"
      say "  equivalent). Get a key from https://console.anthropic.com/."
      say "  Reminder: API usage is billed separately from Pro/Max."
    fi
    say ""
    say "  Then install the cron entry (every 4 hours, off-minute):"
    say ""
    say "      ( crontab -l 2>/dev/null; echo '7 */4 * * * $REPO_DIR/scripts/gardener-run.sh' ) | crontab -"
    say ""
    say "  Verify with: crontab -l | grep gardener"
    say ""
    say "  scripts/gardener-run.sh exits with a clear failure (and notifies"
    say "  via osascript on macOS or \$GARDENER_FAILURE_HOOK) if the key is"
    say "  unset, so you won't silently lose runs."
    ;;
  s|skip|"")
    say ""
    say "  Skipped. To configure later, see docs/SCHEDULING.md."
    ;;
  *)
    say ""
    say "  Unrecognized choice '$SCHEDULING_CHOICE'. Skipped. See docs/SCHEDULING.md."
    ;;
esac

section "Next steps"
say "1. Fill ~/garden/meta/user.md. Ask Claude or Cursor: 'Interview me for my user.md (15 questions).'"
say "2. Bootstrap your voice profile. Ask the agent: 'init my voice from Slack' (invokes garden-voice)."
say "3. (Optional) Seed the vault from connected sources. Ask the agent: 'init my garden from"
say "     connected sources' (invokes garden-bootstrap). One-shot, interactive, you confirm the plan."
say "     Never runs unattended."
say "4. Push the vault to a private GitHub repo:"
say "     cd ~/garden && git remote add origin git@github.com:<you>/garden.git && git push -u origin main"
say "5. Finish the scheduling step you chose in section 6. See $REPO_DIR/docs/SCHEDULING.md for details on either path."
say ""
say "Restart Claude Code to activate hooks, or restart Cursor so it picks up $CURSOR_HOOKS and the vault rules."
