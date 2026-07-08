#!/usr/bin/env bash
# Manage the autopilot dev-run process (config: .autopilot/dev-run.json).
#
# The dev server runs as a SESSION BACKGROUND SHELL (Bash tool with
# run_in_background: true), started by Claude per the autopilot-dev-run
# skill — visible as a session task, exit notifications re-invoke Claude,
# and it dies with the session (no orphans). This script supports it:
#
#   kill    — kill the recorded server process tree, KEEP dev-run.json
#             (used right before Claude starts a fresh background shell)
#   stop    — kill the tree and remove dev-run.json
#   status  — print liveness, command, url, task id
#   hook    — PostToolUse(Bash) entry point: after merge/pull commands
#             (`gh pr merge`, `git pull`), inject an additionalContext
#             reminder telling Claude to restart the dev server now
#             (debounced to one signal per 10s). The hook never blocks
#             and never manages the process itself.
#
# dev-run.json: { "command", "url", "taskId", "pid", "autoRestart",
#                 "lastRestart", "startedBy" }
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
CONF="$PROJECT_DIR/.autopilot/dev-run.json"
SUB="${1:-status}"

have_py() { command -v python3 >/dev/null 2>&1; }

json_get() {
  python3 -c "import json,sys;v=json.load(open(sys.argv[1])).get(sys.argv[2]);print('' if v is None else v)" "$CONF" "$1" 2>/dev/null || true
}

alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }

kill_tree() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do kill_tree "$child"; done
  kill "$pid" 2>/dev/null || true
}

case "$SUB" in
  hook)
    INPUT="$(cat || true)"
    [ -f "$CONF" ] || exit 0
    have_py || exit 0
    [ "$(json_get autoRestart)" = "True" ] || [ "$(json_get autoRestart)" = "true" ] || exit 0
    BASHCMD="$(printf '%s' "$INPUT" | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print((d.get("tool_input") or {}).get("command") or "")' 2>/dev/null || true)"
    printf '%s' "$BASHCMD" | grep -qE 'gh pr merge|git pull' || exit 0
    # Ignore this script's own invocations to avoid signal loops.
    printf '%s' "$BASHCMD" | grep -q 'dev-run.sh' && exit 0
    LAST="$(json_get lastRestart)"; NOW="$(date +%s)"
    if [ -n "$LAST" ] && [ "$LAST" -eq "$LAST" ] 2>/dev/null && [ $((NOW - LAST)) -lt 10 ]; then
      exit 0
    fi
    # Stamp the debounce at signal time so sequential merges emit one reminder.
    python3 - "$CONF" <<'PY' 2>/dev/null || true
import json, sys, time
d = json.load(open(sys.argv[1])); d["lastRestart"] = int(time.time())
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
    RUNCMD="$(json_get command)"; URL="$(json_get url)"
    python3 - "$0" "$RUNCMD" "$URL" <<'PY'
import json, sys
script, cmd, url = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = (
    "autopilot dev-run: a merge/pull just landed and autoRestart is enabled. "
    "Restart the dev server NOW, before continuing other work: "
    f"(1) run `{script} kill` to stop the old process tree; "
    "(2) start a NEW session background shell (Bash tool, run_in_background: true) with the command: "
    f"`echo DEVRUN_PID=$$ && exec {cmd}`; "
    "(3) update .autopilot/dev-run.json: pid (from the DEVRUN_PID line in the task output), taskId (from the spawn result), lastRestart (epoch now); "
    + (f"(4) verify readiness by polling {url}. " if url else "(4) verify readiness via the task output. ")
    + "Then continue what you were doing and mention the restart in your report."
)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ctx}}))
PY
    exit 0
    ;;

  kill)
    [ -f "$CONF" ] || { echo "dev-run is not configured"; exit 0; }
    OLDPID="$(json_get pid)"
    if alive "$OLDPID"; then kill_tree "$OLDPID"; echo "dev-run process tree killed (pid $OLDPID); config kept"; else echo "dev-run process not running; config kept"; fi
    ;;

  stop)
    [ -f "$CONF" ] || { echo "dev-run is not configured"; exit 0; }
    OLDPID="$(json_get pid)"
    if alive "$OLDPID"; then kill_tree "$OLDPID"; echo "dev-run stopped (pid $OLDPID)"; else echo "dev-run process not running"; fi
    rm -f "$CONF"
    ;;

  status)
    [ -f "$CONF" ] || { echo "dev-run: not configured"; exit 0; }
    PID="$(json_get pid)"
    if alive "$PID"; then STATE="running (pid $PID)"; else STATE="NOT running"; fi
    echo "dev-run: $STATE"
    echo "command: $(json_get command)"
    echo "url:     $(json_get url)"
    echo "task:    $(json_get taskId)"
    ;;

  *)
    echo "usage: dev-run.sh {kill|stop|status|hook}" >&2
    exit 1
    ;;
esac
