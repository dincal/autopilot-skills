---
name: autopilot-dev-run
description: Start the project's dev server in the current session, with guaranteed automatic restarts whenever autopilot merges a new feature. Also stop/restart/status.
argument-hint: "[stop | restart | status]"
disable-model-invocation: true
---

# Autopilot Dev Run

Run the current project in dev mode as a managed background process. While it runs, a plugin PostToolUse hook AUTOMATICALLY restarts it after every successful `gh pr merge` / `git pull` executed in a Claude Code session — so the running app always reflects newly merged autopilot features, without relying on anyone remembering to restart it.

Manager script: `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/dev-run.sh` (subcommands: `restart`, `stop`, `status`). State file: `.autopilot/dev-run.json` (gitignored).

Note: the autopilot dev loop auto-starts this at run start when `devRun.autoStart` is true (default) and no dev-run is alive — auto-started entries carry `"startedBy": "autopilot"`. An already-running dev-run is never touched.

## Subcommand arguments

If `$ARGUMENTS` is `stop`, `restart`, or `status`: run `dev-run.sh <subcommand>` and report the output. For `status`, also tail the last ~20 lines of the log if the process is not running (show the user why it died). Done.

Otherwise (no argument) — START:

## Step 1 — Determine the dev command

1. Read `.autopilot/config.json`: use `testing.e2e.runCommand` / `url` / `readyCheck` when set.
2. Otherwise auto-detect from the repo (dev script in package.json, framework CLI, main entrypoint). If detection is ambiguous, ask the user once (AskUserQuestion with the candidates found).
3. The command must be a FOREGROUND dev-mode command (e.g. `npm run dev`, `uvicorn app:app --reload`) — the manager backgrounds it itself. Never wrap it in `&` or `nohup`.

## Step 2 — Start

1. If `.autopilot/dev-run.json` already exists and its pid is alive, report status and ask whether to restart — don't stack a second server.
2. Write `.autopilot/dev-run.json`:
   ```json
   {
     "command": "<dev command>",
     "url": "<base url or null>",
     "logFile": "<abs path>/.autopilot/logs/dev-run.log",
     "autoRestart": true,
     "pid": null,
     "lastRestart": 0
   }
   ```
3. Ensure `.autopilot/dev-run.json` is in `.gitignore` (add if missing).
4. Run `dev-run.sh restart` — it kills any stale tree, starts the command detached, and records the pid.

## Step 3 — Verify readiness

Wait for the app: run `readyCheck` if configured, else poll the url with curl (sensible timeout), else watch the log for a ready line. If startup fails, show the log tail and stop — do not leave a dead entry claiming to run (run `dev-run.sh stop`).

## Step 4 — Report

- The url (if any), log path, pid.
- Explain the guarantee: the plugin's PostToolUse hook restarts this process after every successful `gh pr merge` or `git pull` in a Claude Code session (debounced to one restart per 10s), so autopilot merges are picked up automatically. During an autopilot run, the main checkout sits on the run branch — the dev server serves each feature as it merges.
- State the limitation honestly: merges done OUTSIDE a Claude Code session (e.g. the GitHub web UI) don't trigger the hook until something pulls here; hot-reload dev servers additionally pick up local file edits on their own.
- How to stop: `/autopilot-dev-run stop`.
