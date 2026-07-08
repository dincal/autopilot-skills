---
name: autopilot-design
description: Refine the project's overall look & feel through a user interview — audit the current implementation's design, shape a Style Guide that future goal/todo features must follow, and propose restyling work for what already exists.
argument-hint: "[design direction hints]"
disable-model-invocation: true
---

# Autopilot Design

You are shaping the project's overall look & feel WITH the user: audit what the implemented project currently looks like, interview the user into a concrete design direction, and write it into `design.md`'s **Style Guide** — the living contract every future autopilot feature must follow. You frame the options; the user decides.

User's direction hints (may be empty): $ARGUMENTS

## Step 1 — Load context

Read `.autopilot/config.json` (note `language`), `goal.md` (target users and success criteria shape the design direction — read-only), `todo.md` (upcoming features that will need design), `design.md` (current Style Guide + past decisions), and `tech-design.md` (read-only; frontend stack constraints). If `.autopilot/` is missing, recommend `/autopilot-init` and STOP.

## Step 2 — Audit the current look & feel

1. Run the app (`testing.e2e.runCommand` or auto-detect) and experience it as a user. If a browser tool is available in the session, take screenshots of the main screens to ground the interview in reality.
2. Inventory the UI code: framework, component library, design tokens/theme files, CSS conventions, dark mode support.
3. Write a short audit: what the design currently is (even if accidental), where it is inconsistent, and which upcoming todos will force design decisions.

## Step 3 — Interview

Present the audit first, then interview in 2–3 AskUserQuestion rounds. YOU frame 2–3 concrete candidate directions per topic with a recommendation; the user decides. Never re-ask what `$ARGUMENTS` or the existing Style Guide already answers.

- **Round 1 — direction & tone**: brand personality (e.g. minimal / warm / playful / professional-dense), reference products the user likes, what feeling the target users (from goal.md) should get.
- **Round 2 — visual foundations**: color palette (offer concrete candidates with hex values, semantic roles, dark mode policy), typography (families, scale), spacing/density.
- **Round 3 — structure**: layout & navigation patterns, component conventions (radius, elevation, states), voice & copy tone. Plus: per-area direction for upcoming todo features that need design.

**Design tool integration**: if a design tool is available in this session (e.g. Claude Design / DesignSync, or artifact-based mockups), offer to produce visual candidates there and iterate with the user on real mockups instead of descriptions. The user may also paste links or supply their own mockups — treat those as the strongest signal. If no tooling is available, keep candidates concrete anyway: hex palettes, type scales, named reference apps.

## Step 4 — Write the outcome

1. **Style Guide**: rewrite the `## Style Guide` section of `design.md` in place with the agreed direction — concrete and enforceable (hex values, scale numbers, named patterns), in `config.language`. This section is LIVING: it replaces its previous content; history lives in the Decisions log.
2. **Decision log**: append one dated entry to `## Decisions` summarizing what changed and why, `Decided by: user`.
3. **Restyle backlog**: where the already-built UI violates the new guide, propose todo items (concrete, per-screen/per-component). Add only what the user accepts (multiSelect), as `source: user` items with `notes: from design interview <date>`. Do not add rejected ones.
4. Never touch `goal.md` (goal-level repositioning → recommend `/autopilot-goal`) or `tech-design.md` (stack changes are technical decisions, out of scope here).

## Step 5 — Report

- Show the final Style Guide, the decision entry, and any todos added.
- Note the enforcement path: the dev loop copies relevant Style Guide rules into every UI feature's Goal Prompt constraints, so future features follow this direction automatically.
- Suggest committing design.md (and todo.md if changed).
