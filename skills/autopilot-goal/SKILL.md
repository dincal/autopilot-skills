---
name: autopilot-goal
description: Interview the user about the project's ultimate and short-term goals, then write .autopilot/goal.md with the user's explicit approval.
argument-hint: "[rough goal guidance]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Bash(git *), Bash(gh *), Bash(ls *), Bash(cat *), Bash(date *), Bash(mkdir *), Bash(touch *)
---

# Autopilot Goal Interview

You are writing or revising `.autopilot/goal.md` — the single source of truth for what this project is trying to achieve. Every autopilot development loop is driven by this file, so it must capture the USER's intent, not yours. You may only write it after the user explicitly approves the final draft.

User's rough guidance (may be empty): $ARGUMENTS

## Step 1 — Load context

1. Read `.autopilot/config.json` if it exists and note `language` (default `ko`). Write goal.md in that language. This skill's conversation follows the user's language as usual.
2. Read `.autopilot/goal.md` if it exists. If it does, this is a REVISION: summarize the current goals to the user before interviewing, and only probe what should change.
3. Read `CLAUDE.md`, the README, and the package manifest (package.json / pyproject.toml / go.mod / etc.) to ground your questions in the actual project.
4. If `.autopilot/` does not exist yet, mention that `/autopilot-init` sets up the rest of the files, but continue — this skill may create `.autopilot/` just for goal.md.

## Step 2 — Interview

Run 2–3 rounds of AskUserQuestion. Treat `$ARGUMENTS` as already-given answers; never re-ask what the user has stated there or in an existing goal.md.

- **Round 1 — vision**: the ultimate goal (what the product becomes), target users, and what measurable success looks like.
- **Round 2 — near term**: 3–6 short-term goals for the current horizon; for each, elicit an observable "done when" condition.
- **Round 3 — boundaries** (skip if already clear): non-goals (explicitly out of scope) and constraints (stack, platform, deadline, compliance).

Derive concrete option candidates from what you saw in the repo so the user can pick rather than type, but questions must remain open to free-form answers.

## Step 3 — Draft

Render the complete goal.md following `${CLAUDE_PLUGIN_ROOT}/templates/goal.template.md`:

- Keep the warning comment header (`MANAGED BY /autopilot-goal ONLY ...`) intact.
- **Success Criteria** must be measurable/observable — the dev loop runs the app against these.
- Every **Short-Term Goal** ends with `— done when: <observable condition>`.
- Append to `## History`: `- <YYYY-MM-DD>: <one-line summary of this change>, approved by user` (get the date with `date +%F`).
- Show the COMPLETE draft to the user in your reply — never ask for approval of a document the user hasn't seen in full.

## Step 4 — Consent gate (mandatory)

Ask via AskUserQuestion: "Write this draft to .autopilot/goal.md?" with options:

- **Approve** — write the file as shown.
- **Edit first** — collect the requested changes, update the draft, show it again, re-ask.
- **Cancel** — stop. Write nothing, leave any existing goal.md untouched.

Only after Approve:

1. `mkdir -p .autopilot && touch .autopilot/.goal-consent` — the one-shot consent token consumed by the plugin's write guard. NEVER create this token before the user approves.
2. Write `.autopilot/goal.md` with the Write/Edit tool (never via Bash redirection).

## Step 5 — Follow-up

- If `.autopilot/todo.md` exists and the goals changed, recommend running `/autopilot-sync` — existing todos may now be stale.
- Suggest committing the updated goal.md.
