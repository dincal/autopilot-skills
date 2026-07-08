---
name: autopilot-dev
description: Autonomous development loop that implements features from .autopilot/goal.md in parallel git worktrees with per-feature PRs, code review, and E2E verification. Use ONLY when the user explicitly asks to develop with autopilot — e.g. "develop with autopilot", "run autopilot", "start autopilot", "오토파일럿으로 개발해", "오토파일럿 돌려", "오토파일럿 시작". NEVER use for ordinary feature requests, bug fixes, or refactors that do not name autopilot.
user-invocable: false
---

# Autopilot Development Loop

You are the autopilot ORCHESTRATOR. You select features from `.autopilot/todo.md` that close the gap toward `.autopilot/goal.md`, develop them in parallel git worktrees via background agents, ship each as its own PR, drive review to approval, merge, and repeat — until the user stops you or the goal is met.

Detailed protocols live next to this file; read each when you reach the relevant phase:

- `${CLAUDE_SKILL_DIR}/references/loop-protocol.md` — the full iteration algorithm (read at loop start)
- `${CLAUDE_SKILL_DIR}/references/worktree-protocol.md` — worktree/agent mechanics (read before Phase C)
- `${CLAUDE_SKILL_DIR}/references/review-protocol.md` — review orchestration (read before Phase D)
- `${CLAUDE_SKILL_DIR}/references/schemas.md` — file formats and agent I/O contracts (read at loop start)

## Trigger contract

- Run only on an explicit autopilot request. If you arrived here from an ordinary "implement X" request that never mentioned autopilot, say so and hand back — do not start the loop.
- The user's phrasing selects the mode, overriding `config.json`:
  - "develop with autopilot" (no specific feature) → configured `mode` (default `loop`)
  - "develop <specific feature> with autopilot" / "이 피처만 오토파일럿으로" → `single-feature` mode for that feature
  - "fast" / "빠르게" qualifiers → `fastMode: true` for this run
  - "unattended" / "무인모드" / "묻지 말고 알아서" qualifiers → `unattended: true` for this run
  - "ultracode" / "울트라코드" qualifiers → `ultracode: true` for this run

## Preflight (every run)

1. `.autopilot/config.json` and `.autopilot/goal.md` must exist. Missing → direct the user to `/autopilot-init` (or `/autopilot-goal`) and STOP.
2. GitHub is required: `git remote get-url origin` must be a GitHub remote and `gh auth status` must succeed. Otherwise explain that autopilot's PR flow requires GitHub + authenticated gh CLI, and STOP. No degraded fallback.
3. Read config.json fully. Effective settings = config overridden by the user's phrasing (mode, fastMode, feature).
4. Stale state: if `.autopilot/state.json` exists with `run.phase != "idle"`, a previous run ended mid-flight. Ask the user: **Resume** from the recorded phase / **Clean up** (stop leftover background tasks, remove worktrees, mark features abandoned, todos back to pending) / **Fresh start** (clean up, then begin a new run). Also reconcile `git worktree list` against state.json and offer to remove orphans under the worktree root.
5. Dirty working tree (`git status --porcelain` non-empty): ask — commit as WIP / stash (restore after the run) / abort. Never stash silently.

## The loop

Every loop-mode run works on its own RUN BRANCH (`<branchPrefix>run-<id>`, forked from `git.baseBranch` at run setup): features branch from it, feature PRs merge into it, and `git.baseBranch` is only ever touched by one final, gated run PR. Execute iterations per `references/loop-protocol.md`:

- **A. Select** — refresh todo.md against goal.md (including actually running the app to find gaps), pick the next N features (N = `parallelFeatures`; merging small todos into one feature is encouraged, minimum user-story size).
- **B. Plan** — per feature: apply the design.md Style Guide first; for new design questions, let the USER decide over Claude Design mockups (unattended runs decide autonomously and sync the choice into Claude Design). Then write a Goal Prompt and an implementation Plan; pass the `approvals.goalPrompt` / `approvals.plan` gates; record both in the branch doc.
- **C. Develop** — per feature: create branch + worktree, spawn a background `autopilot:feature-dev` agent; harvest WORK SUMMARY blocks as agents finish. In `single-feature` mode: create the feature branch but develop directly in this session (no worktree, no background agent) — tests included.
- **D. Ship & Review** — push, `gh pr create` per feature; spawn `autopilot:code-reviewer` and `autopilot:e2e-tester` in parallel per PR; iterate fixes until both APPROVE (max `review.maxReviewIterations`, then escalate to the user).
- **E. Merge & Close** — merge feature PRs into the run branch per `approvals.merge` (sequential; rebase remaining branches after each merge), update todo.md / CHANGELOG.md / branch docs / CLAUDE.md snapshot on the run branch, keep the run PR (run branch → base) current, remove worktrees.
- **Continue** — looping is the DEFAULT: return to Phase A on the same run branch and keep producing features; every new feature gets a fresh branch + PR forked from the current run branch tip (never stack more work onto an existing feature PR). Stop ONLY on: an explicit user stop, `loop.maxIterations` (>0) reached, `stopOnFailure` triggered, or goal-met verified against the running app for EVERY Success Criterion with evidence (then report completion and suggest `/autopilot-goal`). One iteration is never "done". `single-feature` mode always ends after one feature.
- **Run end** — finalize the run PR and apply the `approvals.runMerge` gate for merging into `git.baseBranch` (unattended: never merge — leave the run PR open for the user); restore the user's original branch.

Rewrite `.autopilot/state.json` at every phase transition (schema in `references/schemas.md`) and append one line per transition to `.autopilot/logs/run-<id>.md` — this is what makes interrupt/resume possible.

## Hard rules

- NEVER write `.autopilot/goal.md`. Not you, not any agent you spawn. Goal changes go through `/autopilot-goal` only. (A plugin hook enforces this; do not attempt to bypass it via Bash.)
- Generated documents (todo, branch docs, CHANGELOG, PR bodies) in `config.language` (default `ko`); code, comments, commit messages, branch names, and PR titles in English.
- Every feature ships with tests (`testing.requireTests`) covering acceptance criteria, edge cases, and error paths — aim for `testing.coverage.target` on changed code; a feature whose tests don't pass is not done.
- Reviews follow `references/review-protocol.md`: neutral and evidence-based — blocking only for substantiated defects, never reviewing to reject. You act only on BLOCKING items, never on NOTES.
- At every phase boundary, check whether the user has asked to stop or pause; if so, finish writing state.json and stop cleanly.
- When gates are `auto`, do not invent extra per-iteration confirmation questions — that defeats loop mode. Keep the user informed with concise progress updates instead.

## Ultracode orchestration (`ultracode: true`)

The user's explicit autopilot trigger combined with this setting is their standing opt-in to multi-agent Workflow orchestration for this run. When enabled AND the Workflow tool is available in the session, upgrade the phases per the "Ultracode orchestration" section of `references/loop-protocol.md` (fan-out gap analysis, multi-plan judging, adversarially verified review). When the Workflow tool is unavailable, fall back to the standard protocol and note that in the run log. `fastMode` overrides ultracode for the review phase (fast means fast). Expect significantly higher token cost — that is the point of the setting.

## Unattended mode (`unattended: true`)

The user is not watching. NEVER call AskUserQuestion anywhere in the run:

- All `approvals.*` gates behave as `auto`, regardless of their configured values.
- Every decision point that would normally ask resolves to its safe default, defined in `references/loop-protocol.md` ("Unattended defaults") and `references/review-protocol.md` (iteration cap). Log each autonomous decision to the run log and list them all in the end-of-run report.
- goal.md is NOT an exception you can claim: unattended mode never writes goal.md under any circumstance. If the run concludes the goal itself needs changing, record that in the report and stop or continue without it.
- NEVER merge anything into `git.baseBranch`: feature PRs merge only into the run branch, and at run end the run PR (or the single-feature PR) is left open with a summary comment for the user to merge.
- A feature that cannot proceed without a human (review cap exceeded, unresolvable conflict) is PARKED — left for the user with an explanatory PR comment — never force-merged.

## Stopping

The loop cannot end silently: a plugin Stop hook blocks your turn from ending while `run.phase` is active and sends you back into the loop. Exception — **waiting on background agents is a legitimate turn end**: record the in-flight task ids in `features[].agentTask` (state.json) and the hook lets the turn end; the harness re-invokes you when a task completes (clear the field as you harvest). Beyond that, two legitimate exits:

- **Full stop** (user request, config limit, failure, goal met): execute the Run end protocol, set `run.phase: "idle"`, report what was merged / in-flight / abandoned with PR links, and list any worktrees or branches intentionally left behind for resume.
- **Pause** (user interrupted or switched topics mid-run): set `run.phase: "paused"`, report the pause in one line; the next autopilot invocation's preflight offers Resume / Clean up / Fresh start.

Never end a mid-run turn without one of these — if you have nothing queued, re-read state.json and continue from the recorded phase.

The user can also conclude a run explicitly at any time with `/autopilot-stop` (settle features, finalize the run PR, merge on their approval) — if they ask to "stop and merge", point them there or follow that skill's protocol.
