---
name: autopilot-sync
description: Synchronize all .autopilot files and the CLAUDE.md autopilot section with the current state of the repository.
disable-model-invocation: true
---

# Autopilot Sync

Reconcile every autopilot-managed file with reality: the code, git history, and merged PRs. Files must describe what IS, not what was. Write all generated content in `config.json`'s `language` (default `ko`).

If `.autopilot/` does not exist, tell the user to run `/autopilot-init` and STOP.

## Step 1 — Load

Read all of: `.autopilot/config.json`, `goal.md`, `design.md`, `tech-design.md`, `todo.md`, `CHANGELOG.md`, every `branch/*.md`, `CLAUDE.md`, and `.autopilot/state.json` if present (note `lastSyncCommit`).

## Step 2 — Gather reality

- `git log --oneline <lastSyncCommit>..HEAD` (or recent history if no lastSyncCommit), `git tag --sort=-creatordate`
- `gh pr list --state merged --limit 50` and `gh pr list --state open` (skip gracefully if gh/remote unavailable)
- `git branch -a` and `git worktree list`
- Current file tree and, where cheap, actual behavior (run the test suite if `testing.testCommand` is set)

## Step 3 — todo.md

For each pending item, verify against the actual code whether it is genuinely NOT built:

- Implemented items: REMOVE from todo.md (they must be reflected in CHANGELOG / branch docs — add them there if missing).
- Stale statuses (e.g. `selected`/`in-progress` for branches that no longer exist): reset to `pending` with a note.
- Preserve IDs, `source`, priorities, and user wording. NEVER invent new `user`-source items; new gap items you discover are `source: agent`.
- Re-sort by the schema rule: source (user first) → priority → ID.

## Step 4 — design.md & tech-design.md

Append newly observable decisions since last sync as dated entries marked `Decided by: agent (observed from code)`, routed by type:

- UI/UX changes (design system, components, layout/UX flows) → `design.md`
- Technical changes (frameworks, storage, architecture, data model) → `tech-design.md` (create from `${CLAUDE_PLUGIN_ROOT}/templates/tech-design.template.md` if missing)

Append-only: never delete or rewrite existing entries. Exception — entries that historically landed in the wrong file may be MOVED once to the correct file, preserving their text and dates verbatim (note the move in the destination entry).

## Step 5 — CHANGELOG.md

- Fold merged PRs / features since last sync into `[Unreleased]` (format: `- <description> (<feature IDs>, PR #<n>)`).
- If new git tags exist, cut a version section per tag (move the then-unreleased entries under it with the tag date).

## Step 6 — branch/*.md

- Update docs for live branches (status, PR number, work summary from commits).
- Branches merged or deleted: set final status and move their doc to `branch/archive/`.
- Current branch missing a doc: create one from `${CLAUDE_PLUGIN_ROOT}/templates/branch.template.md`.

## Step 7 — CLAUDE.md

Regenerate ONLY the content between `<!-- AUTOPILOT:BEGIN -->` and `<!-- AUTOPILOT:END -->` using `${CLAUDE_PLUGIN_ROOT}/templates/claude-md-section.md` (refresh the `{{PROJECT_SNAPSHOT}}` with the current structure and commands). If the markers are missing, append the section at the end of CLAUDE.md. Never modify anything outside the markers. Also fix clearly outdated run/test commands elsewhere in CLAUDE.md only if you verified the new ones.

## Step 8 — goal.md is READ-ONLY

Never edit goal.md here. If reality suggests it is stale (e.g. every Short-Term Goal's "done when" condition is now met), report that and recommend `/autopilot-goal`.

## Step 9 — Report

- Print a per-file summary of what changed and why (one or two lines each).
- Update `state.json.lastSyncCommit` to the current HEAD (create state.json if missing with just that field).
- Suggest committing the updated files.
