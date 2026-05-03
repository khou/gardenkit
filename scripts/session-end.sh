#!/usr/bin/env bash
# SessionEnd hook for auto-capture into the garden vault inbox.
#
# Reads JSON input from stdin (Claude Code hook contract):
#   { "session_id": "...", "transcript_path": "<jsonl>", "cwd": "...", "reason": "..." }
#
# Extracts user+assistant text from the transcript, pipes through `claude -p`
# with a focused extraction prompt, writes capture files into ~/garden/inbox/.
# Forks the heavy work so the hook returns immediately and doesn't block session shutdown.

set -e

# Source shell profile so claude resolves under non-interactive shells
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" 2>/dev/null || true

VAULT="${GARDEN_VAULT:-$HOME/garden}"
INBOX="$VAULT/inbox"
LOG="$VAULT/.session-end-log"
MIN_WORDS="${GARDEN_CAPTURE_MIN_WORDS:-200}"
MAX_ITEMS="${GARDEN_CAPTURE_MAX_ITEMS:-5}"

mkdir -p "$INBOX"

# Read hook input from stdin
INPUT=$(cat)

# Extract fields with python3 (more reliable than ad-hoc parsing)
if ! command -v python3 >/dev/null 2>&1; then
  echo "$(date): session-end: python3 not found, skipping" >> "$LOG"
  exit 0
fi

TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("transcript_path",""))
except: print("")')
SESSION_ID=$(echo "$INPUT" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("session_id","unknown"))
except: print("unknown")')
REASON=$(echo "$INPUT" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("reason","other"))
except: print("other")')

# Sanity checks — exit 0 (don't fail the session)
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  echo "$(date): session-end: no transcript at '$TRANSCRIPT_PATH', skipping" >> "$LOG"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "$(date): session-end: claude CLI not on PATH, skipping" >> "$LOG"
  exit 0
fi

# Extract user+assistant text only (skip tool results, system messages, etc.)
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

# Skip empty or short transcripts
WORD_COUNT=$(echo "$TRANSCRIPT_TEXT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt "$MIN_WORDS" ]; then
  echo "$(date): session-end: $WORD_COUNT words < $MIN_WORDS threshold, skipping (reason=$REASON)" >> "$LOG"
  exit 0
fi

TS=$(date +%Y-%m-%d-%H%M)
DATE=$(date +%Y-%m-%d)

echo "$(date): session-end: extracting from $SESSION_ID ($WORD_COUNT words, reason=$REASON)" >> "$LOG"

# Build the extraction prompt
PROMPT=$(cat <<EOF
You are extracting noteworthy items from a conversation transcript into a personal knowledge vault.

Read the transcript below and extract ONLY genuinely noteworthy items in these categories:
- Decisions made (with reasoning)
- Things learned — especially non-obvious facts
- Open questions worth tracking
- Factual claims about projects, people, or tools (state, status, opinions held)
- Useful references (URLs with one-line description)

For EACH noteworthy item, write a separate markdown file to $INBOX/ using the Write tool. Use this exact format:

---
type: capture
created: $DATE
source: session-$TS
---

# <one-line summary>

<the content — keep it raw, the gardener will refine and link it later>

Context: <project | person | topic if known>

Filename pattern: $INBOX/$TS-<slug>.md  (slug = 5-7 words from the summary, lowercased, hyphenated)

SKIP entirely:
- Conversational fluff and pleasantries
- Restatements of things already in the vault
- Speculation without commitment
- Trivial or redundant items
- Step-by-step implementation details — only the high-level decision matters

Cap at $MAX_ITEMS captures maximum. Pick the most important.

If nothing genuinely noteworthy emerged, exit without writing anything. Zero captures is a valid outcome.

When done, print a one-line summary like "Captured N items: <comma-separated slugs>" or "No captures from this session."

=== TRANSCRIPT ===
$TRANSCRIPT_TEXT
EOF
)

# Run the extraction in the background so the session-end hook returns immediately
(
  echo "$PROMPT" | claude -p --permission-mode acceptEdits >> "$LOG" 2>&1

  # Commit any new inbox files so they're not lost before the gardener runs
  cd "$VAULT"
  if [ -n "$(git status --porcelain inbox/ 2>/dev/null)" ]; then
    git add inbox/ 2>/dev/null && \
      git commit -m "capture: $TS — auto from session $SESSION_ID" -q 2>/dev/null && \
      echo "$(date): session-end: committed new captures" >> "$LOG"
  else
    echo "$(date): session-end: no new captures written" >> "$LOG"
  fi
) &
disown

exit 0
