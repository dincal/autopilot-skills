---
name: autopilot-todo
description: Interview the user about features they want, then add them to .autopilot/todo.md as user-sourced items following the todo schema.
argument-hint: "[rough feature ideas]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion, Bash(git *), Bash(gh *), Bash(ls *), Bash(cat *), Bash(date *), Bash(mkdir *)
---

# Autopilot Todo Interview

You are adding items to `.autopilot/todo.md` on the USER's behalf. Items created here get `source: user` — the highest rank in feature selection — so they must reflect what the user actually asked for, refined to the todo schema, not your own ideas. Your own gap-analysis ideas belong to the dev loop (`source: agent`), never here.

User's rough feature ideas (may be empty): $ARGUMENTS

## Step 1 — Load context

1. Read `.autopilot/config.json` if present; note `language` (default `ko`) — write todo content in that language (the `story:`/`acceptance:` text; IDs and field names stay as the schema defines).
2. Read `.autopilot/todo.md` in full: the schema legend, existing items, and the highest AP-### ID. Also check `.autopilot/branch/` docs and `CHANGELOG.md` for higher IDs — new IDs continue the global sequence, never reuse.
3. Read `.autopilot/goal.md` (READ-ONLY — never modify it) to understand priorities and scope.
4. If `.autopilot/` does not exist, recommend `/autopilot-init` first; if the user wants to proceed anyway, create `.autopilot/todo.md` from `${CLAUDE_PLUGIN_ROOT}/templates/todo.template.md`. If only `todo.md` is missing, create it from the template and continue.

## Step 2 — Interview

Treat `$ARGUMENTS` as the seed list; never re-ask what it already answers.

1. **Collect ideas**: if the seed is empty or vague, ask what features the user wants. Offer option candidates derived from goal.md's unmet Short-Term Goals as inspiration, but the user's own wording always wins.
2. **Refine each idea** into schema shape via AskUserQuestion rounds (batch related questions; keep it to 2–3 rounds total):
   - the user story — who is it for, what do they get, why (propose a drafted `As a ..., I want ..., so that ...` line for confirmation rather than making the user write it)
   - acceptance criteria — 1–4 observable behaviors (propose drafts; these are what the E2E reviewer will verify)
   - priority P0–P3 (default P1) and any dependency on existing items
3. **Sanity check against reality**: grep the codebase and existing todos. If an idea appears already implemented or duplicates an existing item, tell the user and ask whether to skip, merge into the existing item, or add anyway.

## Step 3 — Draft

Render the new items exactly per the todo schema (legend at the top of todo.md):

- `- [ ] AP-<next> | P<n> | user | pending` with mandatory `story:` line and observable `acceptance:` bullets; `depends-on:`/`notes:` only when meaningful (note the date the user asked, `date +%F`).
- Ideas smaller than a user story: merge them into one item (tell the user which were merged); oversized epics: propose splitting into 2–3 items.

Show ALL drafted items to the user in full.

## Step 4 — Confirm and write

Ask via AskUserQuestion (multiSelect) which drafted items to add — options: each item, plus effectively "none" by selecting nothing / Cancel. Then:

1. Insert the selected items into `## Items` respecting the ordering rule: source (user first) → priority (P0 highest) → ID. Do not touch existing items except to keep the ordering valid.
2. Never remove or edit existing user items without being asked.

## Step 5 — Follow-up

- Report what was added (IDs + one-liners).
- Suggest committing todo.md, and mention the items will be picked up by the next "develop with autopilot" run — or `/autopilot-sync` first if the file looked stale.
