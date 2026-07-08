---
name: autopilot-design
description: Refine the project's overall look & feel with the user — audit the current implementation, iterate real mockups in Claude Design until the user approves them, then write the outcome into design.md's living Style Guide.
argument-hint: "[design direction hints]"
disable-model-invocation: true
---

# Autopilot Design

You are shaping the project's overall look & feel WITH the user: audit what the implemented project currently looks like, interview the user into a concrete direction, iterate REAL mockups in Claude Design until the user explicitly approves them, and only then write the result into `design.md`'s **Style Guide** — the living contract every future autopilot feature must follow. You frame options; the user decides; nothing becomes the Style Guide until the user has approved actual mockups.

User's direction hints (may be empty): $ARGUMENTS

## Design tooling — Claude Design ONLY

Mockups are made in **Claude Design** via the claude-design MCP (`mcp__claude-design__*` tools). Do NOT use other design tools (Figma, Adobe, etc.) even if they are present in the session.

If the claude-design MCP is not available in this session, tell the user how to enable it — `claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp`, then `/design-login` (requires Pro/Max/Team/Enterprise) — and offer to either stop here so they can set it up, or continue with a text-only interview (concrete hex palettes, type scales, reference apps) with the mockup-approval loop explicitly skipped and noted in the report.

## Step 1 — Load context

Read `.autopilot/config.json` (note `language`), `goal.md` (target users and success criteria shape the direction — read-only), `todo.md` (upcoming features that need design), `design.md` (current Style Guide, past decisions, and any recorded Claude Design project id — reuse it), and `tech-design.md` (read-only; frontend stack constraints). If `.autopilot/` is missing, recommend `/autopilot-init` and STOP.

## Step 2 — Audit the current look & feel

1. Run the app (`testing.e2e.runCommand` or auto-detect) and experience it as a user; screenshot main screens if a browser tool is available.
2. Inventory the UI code: framework, component library, design tokens/theme files, dark mode support.
3. Write a short audit: what the design currently is (even if accidental), where it is inconsistent, and which upcoming todos will force design decisions.

## Step 3 — Direction interview

Present the audit, then interview in at most 2 AskUserQuestion rounds — just enough to aim the first mockups; details get settled visually in Step 4. YOU frame 2–3 concrete candidates per topic with a recommendation. Never re-ask what `$ARGUMENTS` or the existing Style Guide already answers.

- **Round 1 — direction & tone**: brand personality (minimal / warm / playful / professional-dense), reference products the user likes, what the target users (from goal.md) should feel.
- **Round 2 — foundations**: color palette candidates (hex + semantic roles + dark mode policy), typography, spacing/density.

## Step 4 — Mockup ping-pong in Claude Design (the heart of this command)

This loop ends ONLY when the user explicitly approves the mockups. There is no iteration cap.

1. **Project**: `list_projects` → reuse the project recorded in design.md (or an obvious match by name); otherwise `create_project` named after the repo. Record the project id/URL as a comment at the top of design.md's Style Guide section so future runs reuse it.
2. **Prepare**: call `get_claude_design_prompt` for authoring guidance and `list_design_systems` to reuse an existing design system where it fits.
3. **Produce**: build mockups of the project's KEY screens (main flow plus one dense/data screen — not just a landing page) applying the interview direction: `write_files`, then `render_preview`.
4. **Show**: give the user the preview / project link (use `update_sharing` if access is needed) so they can inspect the mockups in Claude Design themselves.
5. **Ping-pong**: AskUserQuestion — **Approve these mockups** / request specific changes / try a different direction. Apply feedback with `write_files` + `render_preview` and show again. Repeat until Approve.
6. If the user asks to stop before approving: record the state (project link, direction so far, open questions) as a dated entry in `## Decisions`, do NOT touch the Style Guide, and report how to resume (re-run `/autopilot-design`).

## Step 5 — Write the outcome (only after mockup approval)

1. **Style Guide**: rewrite the `## Style Guide` section of `design.md` in place, distilled from the APPROVED mockups — concrete and enforceable (hex values, type scale, spacing units, component conventions, layout patterns), in `config.language`, with the Claude Design project id/URL comment kept at the top.
2. **Decision log**: append one dated entry to `## Decisions` summarizing what was decided, `Decided by: user`, linking the approved Claude Design project.
3. **Restyle backlog**: where the already-built UI violates the new guide, propose per-screen/per-component todo items; add only what the user accepts (multiSelect) as `source: user` with `notes: from design interview <date>`.
4. Never touch `goal.md` (goal-level repositioning → `/autopilot-goal`) or `tech-design.md`.

## Step 6 — Report

- Show the final Style Guide, the decision entry, the Claude Design project link, and any todos added.
- Note the enforcement path: the dev loop copies relevant Style Guide rules into every UI feature's Goal Prompt constraints, so future features follow the approved design automatically.
- Suggest committing design.md (and todo.md if changed).
