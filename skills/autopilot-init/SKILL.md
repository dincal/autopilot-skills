---
name: autopilot-init
description: Initialize the .autopilot directory (config, goal, design, todo, changelog, branch docs) and the CLAUDE.md autopilot section for this project, optionally wiring up a GitHub repository and taking a project overview.
argument-hint: "[github repo: owner/repo or URL] [project overview]"
disable-model-invocation: true
---

# Autopilot Init

Initialize everything the autopilot plugin needs in this project. Be idempotent: re-running must never destroy user content.

Optional arguments (GitHub repository and/or project overview): $ARGUMENTS

## Step 1 — Git & GitHub preconditions

Parse `$ARGUMENTS`: a leading token shaped like a GitHub repository reference — `owner/repo`, `https://github.com/owner/repo`, or `git@github.com:owner/repo.git` — is the repo (normalize it to `owner/repo`); everything else is the user's rough PROJECT OVERVIEW text (used in Step 2).

**With a repo argument** — make that repository this project's `origin` before anything else. This path requires an authenticated gh CLI: if `gh auth status` fails, explain and STOP. Check existence with `gh repo view <owner/repo>`:

- **The repo EXISTS on GitHub**:
  - cwd is already a git repo → point `origin` at it: add the remote if missing; if `origin` exists and differs from the given address, ask the user before switching. Then `git fetch origin`.
  - cwd is NOT a git repo and is empty → `git clone https://github.com/<owner/repo>.git .` and continue initializing the clone.
  - cwd is NOT a git repo but has files → `git init -b <remote default branch>`, add `origin`, `git fetch origin`. If the remote already has commits, ask the user how to reconcile (integrate the remote history / abort for manual resolution) — never overwrite either side silently.
- **The repo does NOT exist**:
  - Ensure a local repo first (`git init -b main` if needed).
  - Ask the user for visibility (public / private) via AskUserQuestion, then create it: `gh repo create <owner/repo> --<visibility> --source . --remote origin`, adding `--push` when local commits already exist. If there is nothing committed yet, the push happens with the commit suggestion in Step 7.

**Without a repo argument**: run `git rev-parse --is-inside-work-tree`. If this is not a git repository, explain that autopilot requires git (offer to `git init` only if the user asks) and STOP.

**Existing .autopilot/**: if `.autopilot/` already exists, ask via AskUserQuestion:
   - **Repair / re-initialize** — recreate missing files and refresh CLAUDE.md, but NEVER regenerate or overwrite an existing `goal.md`, and preserve existing todo/design/changelog content (only add missing scaffold parts).
   - **Run /autopilot-sync instead** — if the files exist and just look stale, stop here and tell the user to run `/autopilot-sync`.

## Step 2 — Repo survey

Gather, in parallel where possible:

- Stack and tooling: package manifests, lockfiles, frameworks.
- How to run tests (e.g. `npm test`, `pytest`, `go test ./...`) and how to start the app (dev server command, CLI entrypoint). Verify a candidate test command actually runs if cheap to do.
- Default/base branch: `git remote show origin` or `git symbolic-ref refs/remotes/origin/HEAD`, falling back to the current branch. When a repo argument was handled in Step 1, prefer the GitHub default branch.
- GitHub health (skip if already established in Step 1): `git remote get-url origin` (is it GitHub?) and `gh auth status`. If either fails, WARN the user now: the autopilot dev skill requires a GitHub remote and an authenticated `gh` CLI, and will refuse to run without them. Init still proceeds.
- Existing `CLAUDE.md`, README, docs.

**Project overview** — establish a 2–4 sentence statement of what this project is, who it is for, and what it does. Sources, in priority order:

1. Overview text from `$ARGUMENTS` — the user's own words always win; refine wording but never change the meaning.
2. Derived from the survey (README, CLAUDE.md, code) when no argument was given.
3. If neither yields anything meaningful (e.g. a brand-new empty repo), ASK the user for a short overview via AskUserQuestion before proceeding — do not invent one.

If the overview was derived (source 2) and the evidence is thin or ambiguous, confirm it with the user in one question. The established overview feeds the goal interview seed (Step 4), the design.md seeding (Step 5), and the CLAUDE.md project overview (Step 6).

## Step 3 — config.json

1. Start from `${CLAUDE_PLUGIN_ROOT}/templates/config.default.json`.
2. Ask ONE AskUserQuestion round (up to 4 questions) for the settings that matter:
   - `mode` (loop / single-feature) — default loop
   - `parallelFeatures` (1–4) — default 2
   - approval gates (`goalPrompt`/`plan`/`merge`: ask vs auto) — default ask; `fastMode` on/off
   - `language` for generated docs — default ko
3. Fill from the survey: `git.baseBranch`, `testing.testCommand`, `testing.coverage.command` (e.g. `npm test -- --coverage`, `pytest --cov`), `testing.e2e.runCommand`/`url` if confidently detected (otherwise leave null for auto-detection at run time).
4. Write `.autopilot/config.json`.

## Step 4 — goal.md

- If `.autopilot/goal.md` exists: leave it untouched.
- If missing: run the goal interview inline — follow the exact protocol of the `autopilot-goal` skill (read `${CLAUDE_PLUGIN_ROOT}/skills/autopilot-goal/SKILL.md` and execute its Steps 2–4, including the consent gate and the `.goal-consent` token), seeding the interview with the project overview from Step 2. If the user declines to write goal.md, continue initializing the rest but note clearly that the autopilot dev skill cannot run without goal.md.

## Step 5 — Scaffold the rest

Create only what is missing, from `${CLAUDE_PLUGIN_ROOT}/templates/`:

- `design.md` from `design.template.md` — UI/UX design decisions ONLY. Seed it with user-facing conventions you can OBSERVE (design system, component library, layout and UX patterns), each marked `Decided by: agent (observed from code)`.
- `tech-design.md` from `tech-design.template.md` — development design decisions ONLY. Seed it with technical decisions you can OBSERVE from the code (framework choices, architecture, data model, storage), same marking.
- `todo.md` from `todo.template.md` — keep the schema legend header; leave items empty unless the user volunteered features during init (add those as `source: user`).
- `CHANGELOG.md` from `changelog.template.md` — if git tags exist, add one section per existing tag with a one-line summary from `git log` between tags; otherwise just `[Unreleased]`.
- `branch/` directory with a doc for the current branch from `branch.template.md` (fill BRANCH_NAME/DATE/BASE_BRANCH; features/pr may be `-`).

## Step 6 — CLAUDE.md

1. If `CLAUDE.md` does not exist, create it following best practices: the project overview established in Step 2, how to run/test/build (commands verified in Step 2), key directories, conventions. Keep it concise and imperative — commands over prose. If CLAUDE.md exists but lacks an overview, add the established one at the top (outside the autopilot markers).
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
3. Suggest committing the new files (do not commit unless asked). If a GitHub repository was newly created in Step 1 and nothing has been pushed yet, include pushing (`git push -u origin <branch>`) in the suggestion.
