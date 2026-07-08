---
name: autopilot-dev-run
description: Run the project's dev server as a session background shell, with guaranteed restart reminders whenever autopilot merges a new feature. Also stop/restart/status.
argument-hint: "[stop | restart | status]"
disable-model-invocation: true
---

# Autopilot Dev Run

Run the current project in dev mode as a **session background shell** (Bash tool with `run_in_background: true`). Being a session task means: it is visible in the session's task list, its exit re-invokes you (crash → you notice and react), and it dies with the session — no orphan servers. While it runs, a plugin PostToolUse hook injects a restart reminder after every successful `gh pr merge` / `git pull`, so the running app always reflects newly merged autopilot features.

Manager script: `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/dev-run.sh` (subcommands: `kill`, `stop`, `status`). State file: `.autopilot/dev-run.json` (gitignored).

Note: the autopilot dev loop auto-starts this at run start when `devRun.autoStart` is true (default) and no dev-run is alive — auto-started entries carry `"startedBy": "autopilot"`. An already-running dev-run is never touched.

## Subcommand arguments

- `stop` → run `dev-run.sh stop` and report. Done.
- `status` → run `dev-run.sh status`; if the process is not running, also show the tail of the background task output (why it died). Done.
- `restart` → run `dev-run.sh kill`, then perform the Start steps below reusing the recorded command/url. Done.

Otherwise (no argument) — START:

## Step 1 — Determine the dev command

1. Read `.autopilot/config.json`: use `testing.e2e.runCommand` / `url` / `readyCheck` when set.
2. Otherwise auto-detect from the repo (dev script in package.json, framework CLI, main entrypoint). If detection is ambiguous, ask the user once (AskUserQuestion with the candidates found).
3. The command must be a FOREGROUND dev-mode command (e.g. `npm run dev`, `uvicorn app:app --reload`) — never wrap it in `&` or `nohup` yourself.

## Step 2 — Start (session background shell)

1. If `.autopilot/dev-run.json` exists and its pid is alive, report status and ask whether to restart — don't stack a second server.
2. Start with the Bash tool, `run_in_background: true`, command:
   ```
   echo DEVRUN_PID=$$ && exec <dev command>
   ```
   (`exec` makes the recorded shell pid BE the server; the echoed `DEVRUN_PID` line in the task output is the pid.)
3. Read the pid from the task output, then write `.autopilot/dev-run.json`:
   ```json
   {
     "command": "<dev command>",
     "url": "<base url or null>",
     "taskId": "<background task id>",
     "pid": <pid>,
     "autoRestart": true,
     "lastRestart": 0,
     "startedBy": "user"
   }
   ```
4. Ensure `.autopilot/dev-run.json` is in `.gitignore` (add if missing).

## Step 3 — Verify readiness

Run `readyCheck` if configured, else poll the url with curl (sensible timeout), else watch the task output for a ready line. If startup fails, show the output tail and clean up (`dev-run.sh stop`) — never leave a dead entry claiming to run.

## Step 4 — Report

- The url (if any), task id, pid.
- The guarantees: (a) after every successful `gh pr merge` / `git pull`, the plugin hook injects a restart instruction (debounced 10s) — follow it immediately when you see it: `dev-run.sh kill` → new background shell → update dev-run.json; (b) if the server crashes, the background task's exit notification reaches you — inspect the output tail, restart if appropriate, and tell the user what happened.
- Limitation: merges done OUTSIDE a Claude Code session don't trigger the hook until something pulls here; hot-reload dev servers additionally pick up local file edits on their own.
- How to stop: `/autopilot-dev-run stop`.
