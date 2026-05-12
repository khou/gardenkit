#!/usr/bin/env bash
# Scan Claude Code transcripts modified since the last extraction run, and feed
# each one through extract-to-inbox.sh to harvest new captures into the vault.
#
# State: ~/.cache/gardenkit/last-extract-epoch (epoch seconds of newest processed
#   transcript). First run defaults to 7 days ago.
#
# Usage: extract-new-transcripts.sh
# Env:
#   GARDEN_VAULT             vault path (default $HOME/garden)
#   EXTRACT_SETTLE_MINUTES   skip transcripts modified within last N min (default 10)
#   EXTRACT_MAX_PER_RUN      cap transcripts processed per run (default 20)

set -e

VAULT="${GARDEN_VAULT:-$HOME/garden}"
LOG="$VAULT/.extract-log"
STATE_DIR="$HOME/.cache/gardenkit"
STATE="$STATE_DIR/last-extract-epoch"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACTOR="$SCRIPT_DIR/extract-to-inbox.sh"
PROJECTS_DIR="$HOME/.claude/projects"

SETTLE_MINUTES="${EXTRACT_SETTLE_MINUTES:-10}"
MAX_PER_RUN="${EXTRACT_MAX_PER_RUN:-20}"

log() { echo "$(date): extract-new: $*" >> "$LOG"; }

[ -d "$VAULT" ] || { echo "$(date): extract-new: vault $VAULT missing" >&2; exit 1; }
[ -x "$EXTRACTOR" ] || { log "extractor not executable at $EXTRACTOR"; exit 1; }
[ -d "$PROJECTS_DIR" ] || { log "no claude projects dir at $PROJECTS_DIR"; exit 0; }
command -v python3 >/dev/null 2>&1 || { log "python3 not found"; exit 0; }
command -v claude >/dev/null 2>&1 || { log "claude CLI not on PATH"; exit 0; }

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

# Build candidate list: mtime > LAST_RUN AND mtime <= SETTLE_CUTOFF, sorted oldest first.
# Skip: (a) subagent fragments (not standalone sessions); (b) sessions whose cwd
# is the vault or a worktree under it (those are the gardener's own runs).
CANDIDATES=$(find "$PROJECTS_DIR" -name "*.jsonl" -type f -print0 \
  | xargs -0 stat -f "%m %N" 2>/dev/null \
  | awk -v lo="$LAST_RUN" -v hi="$SETTLE_CUTOFF" -v pd="$PROJECTS_DIR" -v ve="$VAULT_ENCODED" \
        '$1 > lo && $1 <= hi && $2 !~ ("^" pd "/" ve "(/|--)")' \
  | grep -v '/subagents/' \
  | sort -n \
  | head -n "$MAX_PER_RUN")

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
