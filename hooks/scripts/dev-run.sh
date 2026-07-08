#!/usr/bin/env bash
# Manage the autopilot dev-run process (config: .autopilot/dev-run.json).
#
# Subcommands:
#   restart — (re)start the dev process from dev-run.json (kills the old tree)
#   stop    — kill the dev process tree and remove dev-run.json
#   status  — print liveness, command, url, log path
#   hook    — PostToolUse(Bash) entry point: reads the tool input from stdin
#             and restarts the dev process after merge/pull commands
#             (`gh pr merge`, `git pull`), debounced to one restart per 10s.
#
# dev-run.json: { "command", "url", "logFile", "autoRestart", "pid", "lastRestart" }
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
    LAST="$(json_get lastRestart)"; NOW="$(date +%s)"
    if [ -n "$LAST" ] && [ "$LAST" -eq "$LAST" ] 2>/dev/null && [ $((NOW - LAST)) -lt 10 ]; then
      exit 0
    fi
    exec "$0" restart
    ;;

  restart)
    [ -f "$CONF" ] || { echo "no dev-run.json — start with /autopilot-dev-run" >&2; exit 1; }
    have_py || { echo "python3 required" >&2; exit 1; }
    RUNCMD="$(json_get command)"
    LOG="$(json_get logFile)"
    OLDPID="$(json_get pid)"
    [ -n "$RUNCMD" ] || { echo "dev-run.json has no command" >&2; exit 1; }
    [ -n "$LOG" ] || LOG="$PROJECT_DIR/.autopilot/logs/dev-run.log"
    if alive "$OLDPID"; then kill_tree "$OLDPID"; sleep 1; fi
    mkdir -p "$(dirname "$LOG")"
    printf '\n===== dev-run (re)start %s =====\n' "$(date '+%F %T')" >> "$LOG"
    ( cd "$PROJECT_DIR" && nohup bash -c "$RUNCMD" >> "$LOG" 2>&1 & echo $! > "$CONF.pid.tmp" )
    NEWPID="$(cat "$CONF.pid.tmp")"; rm -f "$CONF.pid.tmp"
    python3 - "$CONF" "$NEWPID" <<'PY'
import json, sys, time
path, pid = sys.argv[1], int(sys.argv[2])
d = json.load(open(path))
d["pid"] = pid
d["lastRestart"] = int(time.time())
json.dump(d, open(path, "w"), indent=2)
PY
    echo "dev-run started (pid $NEWPID, log: $LOG)"
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
    echo "log:     $(json_get logFile)"
    ;;

  *)
    echo "usage: dev-run.sh {restart|stop|status|hook}" >&2
    exit 1
    ;;
esac
