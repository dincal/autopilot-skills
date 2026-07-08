---
name: autopilot-config
description: Show the current autopilot settings and update .autopilot/config.json through a user interview, validating against the config schema.
argument-hint: "[setting or change, e.g. 'merge auto', 'parallel 3']"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Bash(git *), Bash(ls *), Bash(cat *), Bash(date *)
---

# Autopilot Config

You are updating `.autopilot/config.json` — the settings that control how the autopilot dev loop behaves. Changes here shift real authority between the user and the agent (e.g. `approvals.merge: auto` lets the agent merge PRs without asking), so every change must be explicitly chosen by the user and its implication stated before writing.

User's change request (may be empty): $ARGUMENTS

## Step 1 — Load

1. Read `.autopilot/config.json`. If it does not exist, recommend `/autopilot-init`; if the user prefers to proceed here, start from `${CLAUDE_PLUGIN_ROOT}/templates/config.default.json`.
2. Read `${CLAUDE_PLUGIN_ROOT}/templates/config.schema.json` — the source of truth for valid keys, enums, ranges, and each setting's meaning. Never invent settings that are not in the schema.
3. Show the user a compact summary of the CURRENT settings grouped as: mode & speed (`mode`, `fastMode`, `parallelFeatures`), approval gates (`approvals.*`), review (`review.*`), testing (`testing.*`), git (`git.*`), `language`, loop limits (`loop.*`). Flag any values that differ from the defaults.

## Step 2 — Determine what to change

- If `$ARGUMENTS` names concrete changes (e.g. "merge auto", "parallel 3", "fast mode on"), map them to schema keys and go straight to Step 3 with those.
- Otherwise ask via AskUserQuestion which areas to change (multiSelect over the groups above), then interview each selected area with concrete options:
  - present the current value, the allowed values (from the schema), and one line on the practical consequence of each choice — especially for authority-shifting or cost-shifting settings: `approvals.merge`/`goalPrompt`/`plan` (`auto` = the agent proceeds without asking), `unattended` (never asks anything), `fastMode` (skips E2E, one review round), `ultracode` (multi-agent workflows — much higher token cost), `parallelFeatures` (more worktrees and concurrent agents), `git.mergeMethod`.
  - batch related questions into one round; keep the whole interview to 1–2 rounds.

## Step 3 — Validate and confirm

1. Build the updated config: change ONLY the keys the user chose; preserve everything else verbatim (including keys you didn't touch).
2. Validate against the schema: types, enums (`mode`, gates, `mergeMethod`), ranges (`parallelFeatures` 1–4, `maxReviewIterations` ≥ 1, `maxIterations` ≥ 0). Reject invalid values with an explanation and re-ask instead of silently clamping.
3. Show a before → after diff of exactly the changed keys and confirm via AskUserQuestion (Apply / Adjust / Cancel). Embed the full diff in the Apply option's preview — chat text above the question may not render, so the diff must appear inside the question UI, not only in chat. On Cancel, write nothing.

## Step 4 — Write and follow up

1. Write `.autopilot/config.json` (keep it pretty-printed, key order matching the default template).
2. Report the applied changes and when they take effect: the next autopilot run reads config at preflight — a currently running loop picks changes up at its next iteration boundary, not mid-iteration.
3. Suggest committing config.json.

Never modify `.autopilot/goal.md` or other `.autopilot/` files here — this command owns config.json only.
