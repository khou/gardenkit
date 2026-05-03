#!/usr/bin/env bash
# Generic transcript-to-inbox extractor. Used by both SessionEnd and PreCompact hooks.
#
# Usage in settings.json hook:
#   "command": "/path/to/extract-to-inbox.sh <source-label>"
# where <source-label> is e.g. "session" or "pre-compact".
#
# Reads JSON input from stdin (Claude Code hook contract):
#   { "session_id", "transcript_path", "cwd", "reason"?, "trigger"?, "custom_instructions"? }
#
# Extracts user+assistant text from the transcript, pipes through `claude -p`
# with a focused extraction prompt, writes capture files into ~/garden/inbox/.
# Forks the heavy work so the hook returns immediately.

set -e

SOURCE_LABEL="${1:-unknown}"

# Source shell profile so claude resolves under non-interactive shells
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" 2>/dev/null || true

VAULT="${GARDEN_VAULT:-$HOME/garden}"
INBOX="$VAULT/inbox"
LOG="$VAULT/.extract-log"
MIN_WORDS="${GARDEN_CAPTURE_MIN_WORDS:-200}"
MAX_ITEMS="${GARDEN_CAPTURE_MAX_ITEMS:-5}"

mkdir -p "$INBOX"

# Read hook input from stdin
INPUT=$(cat)

# Extract fields with python3
if ! command -v python3 >/dev/null 2>&1; then
  echo "$(date): extract[$SOURCE_LABEL]: python3 not found, skipping" >> "$LOG"
  exit 0
fi

read_field() {
  echo "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('$1', ''))
except Exception:
    print('')
"
}

TRANSCRIPT_PATH=$(read_field transcript_path)
SESSION_ID=$(read_field session_id)
REASON=$(read_field reason)              # SessionEnd
TRIGGER=$(read_field trigger)            # PreCompact (manual|auto)
CUSTOM_INSTRUCTIONS=$(read_field custom_instructions)  # PreCompact (manual)

# Sanity checks.exit 0 (don't fail the hook chain)
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  echo "$(date): extract[$SOURCE_LABEL]: no transcript at '$TRANSCRIPT_PATH', skipping" >> "$LOG"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "$(date): extract[$SOURCE_LABEL]: claude CLI not on PATH, skipping" >> "$LOG"
  exit 0
fi

# Extract user+assistant text only
TRANSCRIPT_TEXT=$(python3 <<EOF
import json
out = []
with open("$TRANSCRIPT_PATH") as f:
    for line in f:
        try:
            msg = json.loads(line)
        except Exception:
            continue
        t = msg.get("type")
        if t not in ("user", "assistant"):
            continue
        content = msg.get("message", {}).get("content", "")
        text_parts = []
        if isinstance(content, str):
            text_parts.append(content)
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text_parts.append(block.get("text", ""))
        text = "\n".join(text_parts).strip()
        if text:
            out.append(f"<{t}>\n{text}\n")
print("\n".join(out))
EOF
)

WORD_COUNT=$(echo "$TRANSCRIPT_TEXT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt "$MIN_WORDS" ]; then
  echo "$(date): extract[$SOURCE_LABEL]: $WORD_COUNT words < $MIN_WORDS threshold, skipping" >> "$LOG"
  exit 0
fi

TS=$(date +%Y-%m-%d-%H%M)
DATE=$(date +%Y-%m-%d)
SOURCE_TAG="$SOURCE_LABEL-$TS"

META_NOTE=""
[ -n "$REASON" ] && META_NOTE="reason=$REASON "
[ -n "$TRIGGER" ] && META_NOTE="${META_NOTE}trigger=$TRIGGER "
[ -n "$CUSTOM_INSTRUCTIONS" ] && META_NOTE="${META_NOTE}custom='${CUSTOM_INSTRUCTIONS}'"

echo "$(date): extract[$SOURCE_LABEL]: extracting from $SESSION_ID ($WORD_COUNT words) $META_NOTE" >> "$LOG"

# Hint for the extractor if user gave custom compaction instructions
HINT=""
if [ -n "$CUSTOM_INSTRUCTIONS" ]; then
  HINT="

USER HINT: when the user triggered this compaction they specifically asked to preserve: $CUSTOM_INSTRUCTIONS
Prioritize capturing items related to that hint."
fi

PROMPT=$(cat <<EOF
You are extracting noteworthy items from a conversation transcript into a personal knowledge vault.

Read the transcript below and extract ONLY genuinely noteworthy items in these categories:
- Decisions made (with reasoning)
- Things learned.especially non-obvious facts
- Open questions worth tracking
- Factual claims about projects, people, or tools (state, status, opinions held)
- Useful references (URLs with one-line description)
$HINT

For EACH noteworthy item, write a separate markdown file to $INBOX/ using the Write tool. Use this exact format:

---
type: capture
created: $DATE
source: $SOURCE_TAG
---

# <one-line summary>

<the content, raw. The gardener will refine and link it later>

Context: <project | person | topic if known>

Filename pattern: $INBOX/$TS-<slug>.md  (slug = 5-7 words from the summary, lowercased, hyphenated)

SKIP entirely:
- Conversational fluff and pleasantries
- Restatements of things already in the vault
- Speculation without commitment
- Trivial or redundant items
- Step-by-step implementation details (only the high-level decision matters)

Cap at $MAX_ITEMS captures maximum. Pick the most important.

If nothing genuinely noteworthy emerged, exit without writing anything. Zero captures is a valid outcome.

When done, print a one-line summary like "Captured N items: <comma-separated slugs>" or "No captures from this session."

=== TRANSCRIPT ===
$TRANSCRIPT_TEXT
EOF
)

# Run extraction in background so the hook returns immediately
(
  echo "$PROMPT" | claude -p --permission-mode acceptEdits >> "$LOG" 2>&1

  cd "$VAULT"
  if [ -n "$(git status --porcelain inbox/ 2>/dev/null)" ]; then
    git add inbox/ 2>/dev/null && \
      git commit -m "capture: $SOURCE_TAG.auto from session $SESSION_ID" -q 2>/dev/null && \
      echo "$(date): extract[$SOURCE_LABEL]: committed new captures" >> "$LOG"
  else
    echo "$(date): extract[$SOURCE_LABEL]: no new captures written" >> "$LOG"
  fi
) &
disown

exit 0
