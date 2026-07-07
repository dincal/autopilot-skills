---
name: autopilot-init
description: Initialize the .autopilot directory (config, goal, design, todo, changelog, branch docs) and the CLAUDE.md autopilot section for this project.
disable-model-invocation: true
---

# Autopilot Init

Initialize everything the autopilot plugin needs in this project. Be idempotent: re-running must never destroy user content.

## Step 1 — Preconditions

1. Run `git rev-parse --is-inside-work-tree`. If this is not a git repository, explain that autopilot requires git (offer to `git init` only if the user asks) and STOP.
2. If `.autopilot/` already exists, ask via AskUserQuestion:
   - **Repair / re-initialize** — recreate missing files and refresh CLAUDE.md, but NEVER regenerate or overwrite an existing `goal.md`, and preserve existing todo/design/changelog content (only add missing scaffold parts).
   - **Run /autopilot-sync instead** — if the files exist and just look stale, stop here and tell the user to run `/autopilot-sync`.

## Step 2 — Repo survey

Gather, in parallel where possible:

- Stack and tooling: package manifests, lockfiles, frameworks.
- How to run tests (e.g. `npm test`, `pytest`, `go test ./...`) and how to start the app (dev server command, CLI entrypoint). Verify a candidate test command actually runs if cheap to do.
- Default/base branch: `git remote show origin` or `git symbolic-ref refs/remotes/origin/HEAD`, falling back to the current branch.
- GitHub health: `git remote get-url origin` (is it GitHub?) and `gh auth status`. If either fails, WARN the user now: the autopilot dev skill requires a GitHub remote and an authenticated `gh` CLI, and will refuse to run without them. Init still proceeds.
- Existing `CLAUDE.md`, README, docs.

## Step 3 — config.json

1. Start from `${CLAUDE_PLUGIN_ROOT}/templates/config.default.json`.
2. Ask ONE AskUserQuestion round (up to 4 questions) for the settings that matter:
   - `mode` (loop / single-feature) — default loop
   - `parallelFeatures` (1–4) — default 2
   - approval gates (`goalPrompt`/`plan`/`merge`: ask vs auto) — default ask; `fastMode` on/off
   - `language` for generated docs — default ko
3. Fill from the survey: `git.baseBranch`, `testing.testCommand`, `testing.e2e.runCommand`/`url` if confidently detected (otherwise leave null for auto-detection at run time).
4. Write `.autopilot/config.json`.

## Step 4 — goal.md

- If `.autopilot/goal.md` exists: leave it untouched.
- If missing: run the goal interview inline — follow the exact protocol of the `autopilot-goal` skill (read `${CLAUDE_PLUGIN_ROOT}/skills/autopilot-goal/SKILL.md` and execute its Steps 2–4, including the consent gate and the `.goal-consent` token). If the user declines to write goal.md, continue initializing the rest but note clearly that the autopilot dev skill cannot run without goal.md.

## Step 5 — Scaffold the rest

Create only what is missing, from `${CLAUDE_PLUGIN_ROOT}/templates/`:

- `design.md` from `design.template.md` — seed it with design decisions you can OBSERVE from the code (framework choices, architecture, storage), each marked `Decided by: agent (observed from code)`.
- `todo.md` from `todo.template.md` — keep the schema legend header; leave items empty unless the user volunteered features during init (add those as `source: user`).
- `CHANGELOG.md` from `changelog.template.md` — if git tags exist, add one section per existing tag with a one-line summary from `git log` between tags; otherwise just `[Unreleased]`.
- `branch/` directory with a doc for the current branch from `branch.template.md` (fill BRANCH_NAME/DATE/BASE_BRANCH; features/pr may be `-`).

## Step 6 — CLAUDE.md

1. If `CLAUDE.md` does not exist, create it following best practices: short project overview, how to run/test/build (commands verified in Step 2), key directories, conventions. Keep it concise and imperative — commands over prose.
2. Insert the managed autopilot section from `${CLAUDE_PLUGIN_ROOT}/templates/claude-md-section.md`:
   - Replace `{{PROJECT_SNAPSHOT}}` with a compact file-structure overview (top-level directories with one-line purposes) plus the run/test commands.
   - If `<!-- AUTOPILOT:BEGIN -->` ... `<!-- AUTOPILOT:END -->` markers already exist, replace ONLY the content between them. Never touch anything outside the markers.

## Step 7 — Housekeeping

1. Ensure `.gitignore` contains:
   ```
   .autopilot/state.json
   .autopilot/logs/
   .autopilot/.goal-consent
   ```
2. Print a summary: every file created/updated/skipped, warnings (e.g. missing GitHub remote), and next steps — `/autopilot-goal` if goal.md is missing, then "develop with autopilot" to start the loop.
3. Suggest committing the new files (do not commit unless asked).
