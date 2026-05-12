#!/usr/bin/env bash
# Scan Claude Code + Cursor transcripts modified since the last extraction run,
# and feed each one through extract-to-inbox.sh to harvest new captures.
#
# Claude transcripts live at ~/.claude/projects/<cwd-encoded>/*.jsonl
# Cursor transcripts live at ~/.cursor/projects/<workspace-slug>/agent-transcripts/<uuid>/*.jsonl
# Both share the same JSONL message shape (with role/type field difference,
# handled by the extractor).
#
# State: ~/.cache/gardenkit/last-extract-epoch (epoch seconds of newest processed
#   transcript). First run defaults to 7 days ago.
#
# Usage: extract-new-transcripts.sh
# Env:
#   GARDEN_VAULT             vault path (default $HOME/garden)
#   EXTRACT_SETTLE_MINUTES   skip transcripts modified within last N min (default 10)
#   EXTRACT_MAX_PER_RUN      cap transcripts processed per run (default 20)
#   GARDENKIT_CURSOR_PROJECTS_DIR
#                            override Cursor's transcript root if it moves
#                            (default $HOME/.cursor/projects -- undocumented
#                            Cursor internal as of 2026-05, may change)

set -e

VAULT="${GARDEN_VAULT:-$HOME/garden}"
LOG="$VAULT/.extract-log"
STATE_DIR="$HOME/.cache/gardenkit"
STATE="$STATE_DIR/last-extract-epoch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACTOR="$SCRIPT_DIR/extract-to-inbox.sh"
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"
CURSOR_PROJECTS_DIR="${GARDENKIT_CURSOR_PROJECTS_DIR:-$HOME/.cursor/projects}"

SETTLE_MINUTES="${EXTRACT_SETTLE_MINUTES:-10}"
MAX_PER_RUN="${EXTRACT_MAX_PER_RUN:-20}"

log() { echo "$(date): extract-new: $*" >> "$LOG"; }

[ -d "$VAULT" ] || { echo "$(date): extract-new: vault $VAULT missing" >&2; exit 1; }
[ -x "$EXTRACTOR" ] || { log "extractor not executable at $EXTRACTOR"; exit 1; }
command -v python3 >/dev/null 2>&1 || { log "python3 not found"; exit 0; }
command -v claude >/dev/null 2>&1 || { log "claude CLI not on PATH"; exit 0; }

# Need at least one transcript source.
if [ ! -d "$CLAUDE_PROJECTS_DIR" ] && [ ! -d "$CURSOR_PROJECTS_DIR" ]; then
  log "no transcript dirs found (looked at $CLAUDE_PROJECTS_DIR and $CURSOR_PROJECTS_DIR)"
  exit 0
fi

mkdir -p "$STATE_DIR"

# Encode vault path the way Claude Code encodes cwds for ~/.claude/projects/
# (replace / and . with -). Used below to exclude the gardener's own sessions,
# which would otherwise round-trip the gardener's vault edits back into inbox/.
VAULT_ENCODED=$(echo "$VAULT" | sed 's|[./]|-|g')

# Load last-run epoch. First run: 7 days ago to avoid drowning in history.
if [ -f "$STATE" ]; then
  LAST_RUN=$(cat "$STATE")
else
  LAST_RUN=$(date -v -7d +%s 2>/dev/null || date -d '7 days ago' +%s)
fi

NOW=$(date +%s)
SETTLE_CUTOFF=$((NOW - SETTLE_MINUTES * 60))

log "scan since=$LAST_RUN settle_cutoff=$SETTLE_CUTOFF max=$MAX_PER_RUN"

# --- Claude candidates ---
# Skip: (a) subagent fragments (not standalone sessions); (b) sessions whose cwd
# is the vault or a worktree under it (those are the gardener's own runs).
CLAUDE_CANDIDATES=""
if [ -d "$CLAUDE_PROJECTS_DIR" ]; then
  CLAUDE_CANDIDATES=$(find "$CLAUDE_PROJECTS_DIR" -name "*.jsonl" -type f -print0 \
    | xargs -0 stat -f "%m %N" 2>/dev/null \
    | awk -v lo="$LAST_RUN" -v hi="$SETTLE_CUTOFF" -v pd="$CLAUDE_PROJECTS_DIR" -v ve="$VAULT_ENCODED" \
          '$1 > lo && $1 <= hi && $2 !~ ("^" pd "/" ve "(/|--)")' \
    | grep -v '/subagents/' \
    || true)
fi

# --- Cursor candidates ---
# Cursor's vault-cwd guard: skip any session whose workspace-slug encodes a path
# under the vault. Cursor encodes workspaces as e.g.
# "Users-kevin-garden" or "Users-kevin-Library-...-Workspaces-NNN-workspace-json".
# Conservative: drop sessions whose slug starts with the encoded vault path.
CURSOR_CANDIDATES=""
if [ -d "$CURSOR_PROJECTS_DIR" ]; then
  CURSOR_CANDIDATES=$(find "$CURSOR_PROJECTS_DIR" -path "*/agent-transcripts/*/*.jsonl" -type f -print0 \
    | xargs -0 stat -f "%m %N" 2>/dev/null \
    | awk -v lo="$LAST_RUN" -v hi="$SETTLE_CUTOFF" -v cd="$CURSOR_PROJECTS_DIR" -v ve="$VAULT_ENCODED" \
          '$1 > lo && $1 <= hi && $2 !~ ("^" cd "/" ve "(/|--)")' \
    || true)
fi

# Combine and limit. Sorted oldest first.
CANDIDATES=$(printf '%s\n%s\n' "$CLAUDE_CANDIDATES" "$CURSOR_CANDIDATES" \
  | grep -v '^$' \
  | sort -n \
  | head -n "$MAX_PER_RUN" || true)

if [ -z "$CANDIDATES" ]; then
  log "no new transcripts"
  exit 0
fi

PROCESSED=0
NEW_MAX=$LAST_RUN

while IFS= read -r line; do
  [ -z "$line" ] && continue
  MTIME="${line%% *}"
  TRANSCRIPT="${line#* }"
  SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)

  # Synthesize hook-style JSON for extract-to-inbox.sh
  HOOK_INPUT=$(python3 -c "
import json
print(json.dumps({
  'transcript_path': '''$TRANSCRIPT''',
  'session_id': '''$SESSION_ID''',
  'reason': 'scheduled',
  'cwd': ''
}))
")
  log "processing $SESSION_ID (mtime=$MTIME)"
  echo "$HOOK_INPUT" | "$EXTRACTOR" scheduled >> "$LOG" 2>&1 || \
    log "  extractor failed for $SESSION_ID (continuing)"
  PROCESSED=$((PROCESSED + 1))
  [ "$MTIME" -gt "$NEW_MAX" ] && NEW_MAX=$MTIME
done <<< "$CANDIDATES"

echo "$NEW_MAX" > "$STATE"
log "done processed=$PROCESSED new_state=$NEW_MAX"
