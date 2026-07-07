# Loop Protocol — one full iteration

State discipline: before each phase, set `state.json` → `run.phase` and per-feature `status`, and append a line to `.autopilot/logs/run-<id>.md`. Phase values: `selecting → planning → developing → reviewing → merging → docs → idle`.

## Phase A — Select (`phase: selecting`)

1. Read `goal.md` and `todo.md` in full.
2. **Gap analysis against reality** (this is more than transcribing user input):
   - Start the app using `testing.e2e.runCommand` (auto-detect if null; skip gracefully for libraries with no runnable surface and use the test suite + public API instead).
   - Walk goal.md's Success Criteria and each Short-Term Goal's "done when" condition against observed behavior.
   - For every unmet condition with no covering todo item, draft a new todo item (`source: agent`, schema in `schemas.md`, IDs continue the AP-### sequence).
   - Gate: if `approvals.newTodos` is `ask`, present the drafted items (AskUserQuestion, multiSelect) and add only accepted ones; `auto` → add them all. Update todo.md.
3. **Pick N features** (N = `parallelFeatures`; in `single-feature` mode N = 1 and, if the user named the feature, use that):
   - Order strictly: `source: user` first (all user items before any agent item) → priority (P0 highest) → lowest ID. Respect `depends-on`: an item whose dependency is unmerged is not eligible.
   - Composition rule: one feature = one full dev cycle, minimum one user story. MERGE tightly-coupled or too-small todos into a single feature; SPLIT anything too big to land as one reviewable PR. Fewer eligible todos than N → shrink N, never pad with filler.
   - Choose features that can land independently — avoid picking two features that will edit the same files heavily (merge them into one feature instead).
4. For each feature: assign a feature id (`F-<date>-<letter>`), branch name `<git.branchPrefix><ap-ids>-<slug>` (English, kebab-case), mark its todos `selected`, and register it in state.json.

## Phase B — Plan (`phase: planning`)

For each selected feature:

1. **Design check**: if it involves user-facing UI/UX or a significant architectural choice, YOU frame the design first — 2–3 concrete options with a recommendation — then ask the user to decide (AskUserQuestion). For visual design, invite the user to supply mockups or use their design tooling; offer your recommended direction as the default so the loop never blocks indefinitely. Record the outcome as a dated entry in `design.md`.
2. **Goal Prompt** — a one-page brief: Objective, User story, Acceptance criteria (observable; copied/refined from the todo items), Constraints, Out of scope.
   - Gate `approvals.goalPrompt = ask`: show the full text, ask per feature — Approve / Edit (revise and re-ask) / Drop this feature (todo back to `pending`) / Stop autopilot.
3. **Implementation Plan** — explore the codebase and write: approach, files to touch, reusable existing utilities, test plan (which tests prove which acceptance criteria), risks. With N > 1, delegate exploration to parallel read-only Explore agents to protect your own context.
   - Gate `approvals.plan = ask`: same options as above.
4. Write the approved Goal Prompt and Plan into `branch/<sanitized>.md` (create from the branch template; `/` in branch names → `--` in filenames).

## Phase C — Develop (`phase: developing`)

Follow `worktree-protocol.md` for mechanics.

- **Parallel (loop mode)**: per feature — create the worktree + branch, then spawn `autopilot:feature-dev` in the background with the input block defined in `schemas.md`. Record agent/task ids in state.json. As each completes, immediately: parse its `WORK SUMMARY`, write it into the branch doc, set `status: dev-done`, and proceed that feature into Phase D — do NOT wait for all N (pipeline, don't barrier).
- **Single-feature mode**: create the feature branch in the main checkout (`git switch -c <branch> <base>`), develop directly yourself following the same rules as the feature-dev agent (tests mandatory, logical commits, English messages), then continue to Phase D.
- A feature-dev agent that dies or returns without a green test run → `status: failed`; its todos go back to `pending` with a failure note; other features continue. `loop.stopOnFailure` decides whether the loop halts after this iteration.

## Phase D — Ship & Review (`phase: reviewing`)

Per feature as it finishes development:

1. Update any project docs the feature affects (README usage, API docs) inside the worktree; commit.
2. Push: `git -C <worktree> push -u origin <branch>`.
3. Create the PR: `gh pr create --base <baseBranch> --head <branch>` — title in English (conventional style), body in `config.language` following the **PR body schema in `schemas.md`**: it MUST lead with the highlighted "decisions made without user approval" section (compiled from auto-passed gates, agent design decisions, WORK SUMMARY autonomous-decisions/deviations, arbitration overrides), followed by the work summary, then acceptance-criteria checklist and test evidence. Record the PR number in state.json and the branch doc.
4. Run the review cycle per `review-protocol.md` until both reviewers APPROVE, the iteration cap escalates to the user, or the feature is abandoned.

## Phase E — Merge & Close (`phase: merging` → `docs`)

1. Merge gate: `approvals.merge = ask` → one AskUserQuestion listing all approved PRs with links (options per PR: Merge / Hold). `auto` → merge without asking.
2. Merge SEQUENTIALLY: `gh pr merge <n> --<git.mergeMethod>` (add `--delete-branch` if `git.deleteBranchAfterMerge`). After each merge, for every remaining unmerged feature branch: fetch, rebase onto the updated base in its worktree, rerun the test suite, force-push (`--force-with-lease`). Rebase conflicts → spawn a feature-dev fix run in that worktree; if tests still fail, escalate to the user.
3. Per merged feature (`phase: docs`):
   - Remove its todo items from todo.md.
   - Append CHANGELOG `[Unreleased]` entries: `- <description> (<AP-ids>, PR #<n>)`.
   - Branch doc: `status: merged` (next `/autopilot-sync` archives it).
   - If the project file structure changed, refresh the CLAUDE.md managed section snapshot (between the AUTOPILOT markers only).
   - Remove the worktree (`git worktree remove <path>`, then `git worktree prune`).
4. Commit the `.autopilot/` doc updates on the base branch with message `chore(autopilot): close iteration <k>`.

## Loop continuation

1. Increment `run.iteration`. Report the iteration compactly: merged PRs, failed/abandoned features, todo count remaining.
2. Stop when: user asked; `loop.maxIterations` > 0 reached; `stopOnFailure` and something failed; or goal met (all Success Criteria verified in Phase A of the NEXT iteration — goal completion is always judged against the running app, not assumptions). Otherwise continue with Phase A.
3. `single-feature` mode: always stop after Phase E, with `run.phase: "idle"`.

## Unattended defaults (`unattended: true`)

No AskUserQuestion anywhere. Each decision point that normally asks resolves as follows — always logged to the run log and listed in the end-of-run report:

- **Dirty tree at preflight** → `git stash push -u -m "autopilot-unattended-<runId>"`; restore the stash when the run ends (success or not).
- **Stale state.json** → resume from the recorded phase when state and worktrees are consistent; otherwise clean up (stop leftover tasks, remove worktrees, todos back to `pending`) and start fresh.
- **Orphan worktrees at preflight** → remove them (only paths under the worktree root).
- **Phase A, `approvals.newTodos`** → auto: add all drafted gap items.
- **Phase B, design check** → decide the design yourself (your recommended option), record it in design.md as `Decided by: agent (unattended run)`.
- **Phase B, `approvals.goalPrompt` / `approvals.plan`** → auto.
- **Phase D, review iteration cap exceeded** → PARK the feature: see review-protocol "Unattended". Never merge a PR that reviewers did not approve.
- **Phase E, `approvals.merge`** → auto-merge approved PRs.
- **Phase E, risky rebase conflict / tests failing after rebase and one fix attempt** → park the feature the same way; continue with the rest.
- **Goal ambiguity** → never write goal.md; interpret conservatively (prefer the literal Success Criteria) and note the ambiguity in the report.

Parked features: leave the branch and open PR intact, post a `gh pr comment` in `config.language` explaining what blocks it, set feature status `abandoned` in state.json, and set the underlying todos to `blocked` with a note referencing the PR — `blocked` items are not re-selected in later iterations, which prevents an unattended loop from endlessly recreating the same stuck feature.
