#!/usr/bin/env bash
# PreToolUse guard for .autopilot/goal.md.
#
# goal.md may only be written after explicit user consent. /autopilot-goal
# creates a one-shot token (.autopilot/.goal-consent) right after the user
# approves the draft; this guard consumes the token (valid < 15 minutes) and
# denies any goal.md write without it.
#
# Modes:
#   file — Write/Edit/MultiEdit/NotebookEdit: inspect tool_input.file_path
#   bash — Bash: best-effort scan of tool_input.command for writes to goal.md
#
# Requires python3 for JSON parsing; if python3 is missing the guard fails
# open (allows) rather than false-blocking unrelated edits — the prompt-level
# rule in every autopilot skill/agent remains as the second layer.
set -euo pipefail

MODE="${1:-file}"
INPUT="$(cat || true)"

allow() { exit 0; }

deny() {
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Writing .autopilot/goal.md requires explicit user consent. Run /autopilot-goal to interview the user and obtain approval; it creates a one-shot consent token before writing."}}
JSON
  exit 0
}

command -v python3 >/dev/null 2>&1 || allow

TARGET="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tool_input = data.get("tool_input") or {}
if sys.argv[1] == "bash":
    print(tool_input.get("command") or "")
else:
    print(tool_input.get("file_path") or tool_input.get("notebook_path") or "")
' "$MODE" 2>/dev/null || true)"

[ -n "$TARGET" ] || allow

if [ "$MODE" = "bash" ]; then
  # Only flag commands that both mention goal.md and look like a write
  # (redirection or a mutating command). Read-only access stays allowed.
  printf '%s' "$TARGET" | grep -qE '\.autopilot/+goal\.md' || allow
  printf '%s' "$TARGET" | grep -qE '(>>?|[|[:space:]]tee[[:space:]]|^tee[[:space:]]|[[:space:]](cp|mv|rm|truncate|dd)[[:space:]]|sed[^|]*-i)' || allow
else
  printf '%s' "$TARGET" | grep -qE '(^|/)\.autopilot/goal\.md$' || allow
fi

# A goal.md write is happening — require a fresh one-shot consent token.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
TOKEN="$PROJECT_DIR/.autopilot/.goal-consent"

if [ -f "$TOKEN" ] && [ -n "$(find "$TOKEN" -mmin -15 2>/dev/null)" ]; then
  rm -f "$TOKEN"
  allow
fi

deny
