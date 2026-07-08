#!/usr/bin/env bash
# Stop hook: keep the autopilot dev loop alive.
#
# Failure mode this fixes: mid-run, the orchestrator ends its turn silently
# (e.g. after an iteration report) and the loop dies with no message. While
# .autopilot/state.json has run.phase outside {idle, paused}, this hook blocks
# the stop and bounces Claude back into the loop.
#
# Safety valve: a progress-aware counter (.autopilot/.stop-guard) caps
# consecutive blocks on the SAME phase+iteration at MAX_NUDGES, so a genuinely
# stuck run can still stop — the next autopilot invocation's preflight offers
# Resume/Clean up/Fresh start. Any phase or iteration change resets the count.
set -euo pipefail

INPUT="$(cat || true)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE="$PROJECT_DIR/.autopilot/state.json"
GUARD="$PROJECT_DIR/.autopilot/.stop-guard"
MAX_NUDGES=3

[ -f "$STATE" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

SNAPSHOT="$(python3 - "$STATE" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        state = json.load(f)
except Exception:
    sys.exit(0)
run = state.get("run") or {}
phase = run.get("phase", "idle")
if phase in ("idle", "paused"):
    sys.exit(0)
# Waiting on background agents is a legitimate turn end: the harness
# re-invokes the orchestrator when a tracked task completes. Feature-level
# work lives in features[].agentTask; run-level work (gap-analysis
# workflows, planning explores) lives in run.agentTask.
if run.get("agentTask"):
    sys.exit(0)
features = state.get("features") or []
if any(f.get("agentTask") for f in features if isinstance(f, dict)):
    sys.exit(0)
print(f"{phase}:{run.get('iteration', 0)}")
PY
)"

if [ -z "$SNAPSHOT" ]; then
  rm -f "$GUARD"
  exit 0
fi

COUNT=1
if [ -f "$GUARD" ]; then
  PREV="$(cat "$GUARD" 2>/dev/null || true)"
  PREV_SNAP="${PREV%|*}"
  PREV_COUNT="${PREV##*|}"
  if [ "$PREV_SNAP" = "$SNAPSHOT" ] && [ "$PREV_COUNT" -eq "$PREV_COUNT" ] 2>/dev/null; then
    COUNT=$((PREV_COUNT + 1))
  fi
fi

if [ "$COUNT" -gt "$MAX_NUDGES" ]; then
  # No progress after repeated nudges — allow the stop; resume handles recovery.
  rm -f "$GUARD"
  exit 0
fi

printf '%s|%s' "$SNAPSHOT" "$COUNT" > "$GUARD"

PHASE="${SNAPSHOT%%:*}"
cat <<JSON
{"decision":"block","reason":"An autopilot run is still ACTIVE (state.json run.phase: ${PHASE}) and no background work is recorded as in flight. Do not end the turn silently. Read .autopilot/state.json and continue the loop from that phase per the autopilot-dev protocol. If you ARE waiting on background agents, record their task ids in state.json — features[].agentTask for feature work (dev agents, reviewers) or run.agentTask for run-level work (gap-analysis workflows, planning explores) — and this hook then allows the turn to end (the harness re-invokes you on completion). To stop legitimately: if a stop condition fired (user stop, maxIterations, stopOnFailure, goal met), execute the Run end protocol and set run.phase to \"idle\"; if the user interrupted or changed topic, set run.phase to \"paused\" and report the pause in one line before stopping."}
JSON
exit 0
