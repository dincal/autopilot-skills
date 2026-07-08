# Loop Protocol — one full iteration

State discipline: before each phase, set `state.json` → `run.phase` and per-feature `status`, and append a line to `.autopilot/logs/run-<id>.md`. Phase values: `selecting → planning → developing → reviewing → merging → docs → idle` (plus `paused` for a suspended run).

**The loop cannot stop silently.** A plugin Stop hook blocks your turn from ending while `run.phase` is active (anything other than `idle`/`paused`) and bounces you back with instructions. The ONLY legitimate ways to stop are: complete the Run end protocol (→ `idle`), or suspend with `run.phase: "paused"` + a one-line pause report (when the user interrupts or changes topic). If you find yourself with nothing to do mid-run, you are wrong — re-read state.json and continue from the recorded phase.

## Run setup (once per run, before iteration 1)

Loop mode only — single-feature mode works directly against `git.baseBranch` with no run branch:

1. Run id `run-<YYYYMMDD>-<HHmm>` → run branch `<git.branchPrefix>run-<id>` (e.g. `autopilot/run-20260707-1530`).
2. `git fetch origin`; create the run branch from `origin/<git.baseBranch>`; `git push -u origin <run branch>`; check it out in the main checkout. Record the branch the user was on in `state.json.run.previousBranch` for restoration at run end.
3. Record `run.branch` in state.json. Every feature branch of this run forks from and merges into the RUN branch. `git.baseBranch` is touched by exactly one thing: the final run PR (see "Run end") — never by direct merges or commits.

## Phase A — Select (`phase: selecting`)

1. Read `goal.md` and `todo.md` in full.
2. **Gap analysis** — reconcile the goal with where the project actually is (more than transcribing user input): read goal.md's Success Criteria and each Short-Term Goal's "done when" condition, and judge each against the current project state — the codebase, and the running app where a runnable surface exists (start it with `testing.e2e.runCommand`, auto-detect if null; libraries with no runnable surface → the test suite + public API). For every unmet condition with no covering todo item, draft a new todo item (`source: agent`, schema in `schemas.md`, IDs continue the AP-### sequence).
   - Gate: if `approvals.newTodos` is `ask`, present the drafted items (AskUserQuestion, multiSelect) and add only accepted ones; `auto` → add them all. Update todo.md.
   - If you run gap analysis via background agents or a workflow, record the task/workflow ids in `state.json.run.agentTask` before ending the turn (run-level counterpart of `features[].agentTask` — the Stop hook honors it) and clear it when you harvest.
3. **Pick N features** (N = `parallelFeatures`; in `single-feature` mode N = 1 and, if the user named the feature, use that):
   - Order strictly: `source: user` first (all user items before any agent item) → priority (P0 highest) → lowest ID. Respect `depends-on`: an item whose dependency is unmerged is not eligible.
   - Composition rule: one feature = one full dev cycle, minimum one user story. MERGE tightly-coupled or too-small todos into a single feature; SPLIT anything too big to land as one reviewable PR.
   - **N is a CEILING, not a quota**: pick fewer than N whenever fewer independent, well-sized features exist — because eligible todos ran short or dependencies block items. Never pad with filler features to reach N; running 2 good features under a parallelFeatures of 4 is correct behavior.
   - Independence is CONCEPTUAL (no dependency between the features), not file-level: worktrees isolate working copies, and overlapping edits surface as ordinary rebase conflicts with a defined resolution path in Phase E. Incidental overlap (two features each adding a line to the same routes file) is fine. Treat only HEAVY overlap — two todos rewriting the same module — as a smell of hidden coupling that usually means they belong in one feature.
4. For each feature: assign a feature id (`F-<date>-<letter>`), branch name `<git.branchPrefix><ap-ids>-<slug>` (English, kebab-case), mark its todos `selected`, and register it in state.json.

## Phase B — Plan (`phase: planning`)

For each selected feature:

1. **Branch doc first (consent artifact)**: at the START of Phase B, before any gate, create `branch/<sanitized>.md` in the main checkout from the branch template (`/` in branch names → `--` in filenames). Every draft the user is asked to approve is written into this file BEFORE the gate fires — assistant chat text between tool calls may not be rendered to the user, so they must never be asked to approve something they cannot see. The doc belongs to its FEATURE branch: it is committed there the moment that branch is created in Phase C (not on the run branch), then updated on the feature branch through dev/review, so it rides the feature PR and lands on the run branch at merge. That is what keeps it a tracked file — an uncommitted branch doc was being clobbered by the Phase E run-branch pull/rebase and its consent artifact + audit trail lost. The file is the durable source of truth; each gate additionally embeds the draft inside the question itself (see the gates below).
2. **Design check**: for any user-facing feature, FIRST consult `design.md`'s `## Style Guide` — when it answers the question, apply it WITHOUT asking, and copy the relevant rules into the feature's Goal Prompt constraints. For genuinely new design questions the guide doesn't answer, design tooling is **Claude Design ONLY** (the claude-design MCP; never other design tools):
   - **Attended**: produce 2–3 mockup candidates in the project's Claude Design project (reuse the id recorded in design.md; `create_project` if none) with `write_files` + `render_preview`, and let the USER decide via AskUserQuestion (pick one / request changes / decide without mockups). Apply requested changes and re-ask; the user's choice is final. Record it in `design.md` `## Decisions` with the mockup link.
   - **Unattended**: decide yourself (your recommended option) AND keep Claude Design in sync — write the chosen design into the Claude Design project (`write_files` + `render_preview`) so the user can review what was designed later; record in `## Decisions` as `Decided by: agent (unattended run)` with the mockup link, and surface it in the PR's autonomous-decisions section and the run report.
   - claude-design MCP unavailable → attended: 2–3 text options with a recommendation (AskUserQuestion); unattended: decide and record in `## Decisions` only, noting the missing MCP.
   Route non-UI decisions as before: development/architecture → `tech-design.md`. Never rewrite the Style Guide from the loop — that belongs to `/autopilot-design`. If the project has no Style Guide yet and the iteration is UI-heavy, suggest `/autopilot-design` in the iteration report (but do not block on it).
3. **Goal Prompt** — a one-page brief: Objective, User story, Acceptance criteria (observable; copied/refined from the todo items), Constraints, Out of scope. Write the DRAFT into the branch doc's `## Goal Prompt` section BEFORE gating.
   - Gate `approvals.goalPrompt = ask`: ask per feature with AskUserQuestion — the question text MUST name the branch doc path, and the Approve option's `preview` field MUST embed the full draft text (the file is the durable source of truth; the preview is the in-question copy). Options: Approve / Edit (revise and re-ask) / Drop this feature (todo back to `pending`) / Stop autopilot.
4. **Implementation Plan** — the SAME WEIGHT as the Goal Prompt: a short brief, not a blueprint (format in `schemas.md`): Approach (a few sentences on how it will work), Boundaries (what it must NOT touch), Test plan (which tests prove which acceptance criteria), Risks. Never enumerate files or prescribe function-level edits — the feature-dev agent explores the codebase itself and owns implementation choices; over-specified plans go stale and generate deviation noise. Write the DRAFT into the branch doc's `## Plan` section BEFORE gating.
   - Gate `approvals.plan = ask`: same mechanics and option set as the goalPrompt gate — branch doc path named in the question text, full draft embedded in the Approve option's `preview`.
5. **Gate outcomes** (both gates): **Approve** → the draft already in the branch doc IS the approved version; no separate write step. **Edit** → update the branch doc in place, then re-ask. **Drop this feature** → return its todos to `pending`; delete the branch doc if nothing was developed yet, otherwise set its `status: abandoned`. **Stop autopilot** → run end protocol.

## Phase C — Develop (`phase: developing`)

Follow `worktree-protocol.md` for mechanics.

- **Parallel (loop mode)**: per feature — create the worktree + branch, then **commit the branch doc onto the new feature branch as its first commit**: write `<worktree>/.autopilot/branch/<doc>.md` from the Phase B consent artifact and `git -C <worktree> add .autopilot/branch/<doc>.md && git -C <worktree> commit -m "docs(autopilot): branch doc <ap-ids>"`, then drop the transient main-checkout copy. Do this BEFORE spawning any agent, so the write never races the dev agent. Then spawn `autopilot:feature-dev` in the background with the input block defined in `schemas.md`. Record agent/task ids in state.json. As each completes, immediately: parse its `WORK SUMMARY`, write it into the branch doc **in the worktree and commit it on the feature branch** (agent has returned — no race), set `status: dev-done`, and proceed that feature into Phase D — do NOT wait for all N (pipeline, don't barrier).
- **Single-feature mode**: create the feature branch in the main checkout (`git switch -c <branch> <base>`), commit the branch doc onto it as the first commit, then develop directly yourself following the same rules as the feature-dev agent (tests mandatory, logical commits, English messages), then continue to Phase D.
- A feature-dev agent that dies or returns without a green test run → `status: failed`; its todos go back to `pending` with a failure note; other features continue. `loop.stopOnFailure` decides whether the loop halts after this iteration.

## Phase D — Ship & Review (`phase: reviewing`)

Per feature as it finishes development:

1. Update any project docs the feature affects (README usage, API docs) inside the worktree; commit.
2. Push: `git -C <worktree> push -u origin <branch>`.
3. Create the PR: `gh pr create --base <run branch> --head <branch>` (single-feature mode: `--base <git.baseBranch>`) — title in English (conventional style), body in `config.language` following the **PR body schema in `schemas.md`**: it MUST lead with the highlighted "decisions made without user approval" section (compiled from auto-passed gates, agent design decisions, WORK SUMMARY autonomous-decisions/deviations, arbitration overrides), followed by the work summary, then acceptance-criteria checklist and test evidence. Record the PR number in state.json, and in the branch doc: set the PR number and `status: merged` (pre-marked: in this flow approval leads to merge; live review progress is tracked in `state.json` `features[].status`, not the doc), then commit that on the feature branch in the worktree and **push it** (`git -C <worktree> commit` + `push`) so the updated doc actually rides the PR — a commit that is never pushed before the Phase E merge would land on the run branch still reading `in-progress`. If the PR is later closed without merging, correct the doc to `status: abandoned`.
4. Run the review cycle per `review-protocol.md` until both reviewers APPROVE, the iteration cap escalates to the user, or the feature is abandoned.

## Phase E — Merge & Close (`phase: merging` → `docs`)

1. Merge gate: `approvals.merge = ask` → one AskUserQuestion listing all approved feature PRs with links (options per PR: Merge / Hold). `auto` → merge without asking. Feature PRs merge into the RUN branch, never into `git.baseBranch`.
2. Merge SEQUENTIALLY: `gh pr merge <n> --<git.mergeMethod>` (add `--delete-branch` if `git.deleteBranchAfterMerge`). After each merge, for every remaining unmerged feature branch: fetch, rebase onto the updated run branch in its worktree, rerun the test suite, force-push (`--force-with-lease`). Rebase conflicts → spawn a feature-dev fix run in that worktree; if tests still fail, escalate to the user.
3. Per merged feature (`phase: docs`):
   - Remove its todo items from todo.md.
   - Append CHANGELOG `[Unreleased]` entries: `- <description> (<AP-ids>, PR #<n>)`.
   - Branch doc: arrived on the run branch with THIS feature's merge (it lived on the feature branch), already `status: merged` from PR creation — no write here; the next `/autopilot-sync` archives it.
   - If the project file structure changed, refresh the CLAUDE.md managed section snapshot (between the AUTOPILOT markers only).
   - Remove the worktree (`git worktree remove <path>`, then `git worktree prune`).
4. Pull the RUN branch first (the feature merges happened on GitHub — this also brings each merged feature's branch doc onto the run branch), THEN commit the remaining shared `.autopilot/` doc updates — todo.md, CHANGELOG, and the CLAUDE.md snapshot (branch docs are NOT written here; they arrived via merge) — with message `chore(autopilot): close iteration <k>`, and push. `git add` ONLY those named files — never `git add -A`/`git add .autopilot`, which would stage a not-yet-merged feature's Phase B branch doc (still untracked in the main checkout) onto the run branch, off its own feature branch. Never `reset --hard`/`clean` the main checkout in a way that discards uncommitted `.autopilot/` work. Single-feature mode: commit the shared updates on the feature branch before the PR instead.
   - If a dev-run is active (`.autopilot/dev-run.json` exists), the plugin's PostToolUse hook injects a restart instruction after your merge/pull commands — execute it right then (`dev-run.sh kill` → new session background shell → update dev-run.json) and mention the restart in the iteration report.
5. Run PR: after the first feature merge of the run, open the run PR — `gh pr create --base <git.baseBranch> --head <run branch>` — with the body per the "Run PR body" schema in `schemas.md`. The run PR then STAYS OPEN and grows across iterations (keep its body current with `gh pr edit`); it is finalized and gated only at run end, and its existence never justifies stopping the loop.

## Loop continuation

**Looping is the default.** After Phase E, return to Phase A on the SAME run branch and keep producing features — a run accumulates features indefinitely until an explicit stop condition fires. One iteration is never "done"; opening the run PR does not mean the run is ending.

1. Increment `run.iteration`. Report compactly: merged feature PRs, failed/abandoned features, todos remaining. Then continue — do NOT ask "should I continue?" (in loop mode continuing IS the user's standing instruction; they stop by saying so).
2. The next iteration's features fork from the CURRENT run branch tip (which now contains everything merged so far), and each gets a FRESH feature branch and a FRESH feature PR. NEVER stack follow-up features onto an existing feature branch or push more work onto an already-open/merged feature PR.
3. Stop ONLY when one of these fires:
   - the user asked to stop or pause;
   - `loop.maxIterations` > 0 and the count is reached (0 means infinite);
   - `stopOnFailure` is true and a feature failed this iteration;
   - the goal is met — a HIGH bar: EVERY Success Criterion in goal.md verified against the actually-running app during Phase A, with per-criterion evidence listed in the final report. Any criterion unverified or ambiguous → the goal is NOT met; generate the next gap todos and continue.
4. `single-feature` mode: always stop after Phase E, with `run.phase: "idle"`.

## Run end (any stop reason: user stop, limits, failure, goal met)

1. Finalize the run PR body: iterations run, merged feature PRs (links), parked/failed features, todo & changelog updates, cumulative autonomous decisions, aggregate test/coverage evidence.
2. Apply the `approvals.runMerge` gate for merging the run branch into `git.baseBranch`:
   - `ask` → AskUserQuestion: Merge now / Leave the run PR open for later.
   - `auto` → `gh pr merge <run pr> --<git.mergeMethod>`.
   - Either merge path adds `--delete-branch` when `git.deleteBranchAfterMerge` is true, so the run branch is removed locally and on origin after merging.
   - **Unattended: NEVER merge into the base branch** regardless of the setting — leave the run PR open with a closing comment summarizing the run; the user merges when ready.
3. If the run merged zero features: open no run PR and delete the run branch (local and origin).
4. Restore the main checkout to `state.json.run.previousBranch` and restore any preflight stash. Set `run.phase: "idle"`.

## Ultracode orchestration (`ultracode: true`)

When enabled and the Workflow tool exists in the session, upgrade these phases. Worktree lifecycle, pushes, PRs, merges, and state remain orchestrator-owned exactly as specified above — workflows never push, merge, or write `.autopilot/` files:

- **Phase A gap analysis** → one workflow: parallel finder agents, one per Success Criterion / Short-Term Goal (each runs or inspects the app against its criterion), then a dedup stage that merges overlapping gaps before todo drafting. Replaces the single-pass gap analysis; record the workflow id in `run.agentTask` while it runs.
- **Phase B planning (per feature)** → one workflow: 2–3 independent plan drafts from different angles (e.g. minimal-change, clean-architecture, test-first), a judge stage that scores them against the Goal Prompt, and a synthesis of the winner grafting the runners-up's best ideas. The synthesized plan still passes the `approvals.plan` gate as usual.
- **Phase C development (per feature)** → author the workflow yourself: whatever orchestration builds this feature fastest and most correctly (fan-out/fan-in, pipeline, judge panel — or a single agent when that's optimal). Hard constraints only:
    1. Work only inside the feature's worktree.
    2. Same-tree parallel writers need disjoint file ownership; overlapping scopes only via per-agent isolated branches, merged (conflicts resolved) at fan-in.
    3. Done = full suite green + `testing.coverage.target`; can't reach green → feature `failed`, no partial ships.
    4. Final synthesis emits the standard WORK SUMMARY.
    5. No push, no `gh`, no `.autopilot/` writes — worktree/push/PR stay with the orchestrator.
    6. Workflow tool missing or the workflow fails → standard single agent, logged.
- **Phase D code review (per PR)** → one workflow replacing the single code-reviewer agent: dimension finders (correctness, security, tests/coverage, acceptance-criteria) fan out over the PR diff, then EVERY candidate blocking item is adversarially verified by 2–3 independent skeptic agents prompted to refute it — only items surviving majority verification become BLOCKING (whitelist rules still apply; unverified items become NOTES). The e2e-tester agent still runs separately as specified. `review.reviewerModel` applies to workflow review agents too.

Rules: `fastMode` overrides ultracode for Phase D (skip the review workflow, use the standard critical-only reviewer). If a workflow fails or the Workflow tool is unavailable, fall back to the standard protocol for that phase and log it. Log each workflow run (phase, agent count) in the run log; iteration reports mention ultracode usage.

## Unattended defaults (`unattended: true`)

No AskUserQuestion anywhere. Each decision point that normally asks resolves as follows — always logged to the run log and listed in the end-of-run report:

- **Dirty tree at preflight** → `git stash push -u -m "autopilot-unattended-<runId>"`; restore the stash when the run ends (success or not).
- **Stale state.json** → resume from the recorded phase when state and worktrees are consistent; otherwise clean up (stop leftover tasks, remove worktrees, todos back to `pending`) and start fresh.
- **Orphan worktrees at preflight** → remove them (only paths under the worktree root).
- **Phase A, `approvals.newTodos`** → auto: add all drafted gap items.
- **Phase B, design check** → decide the design yourself (your recommended option) and, when the claude-design MCP is available, write the chosen design into the project's Claude Design project (`write_files` + `render_preview`) so the user can review it later. Record it as `Decided by: agent (unattended run)` with the mockup link — `design.md` for UI/UX, `tech-design.md` for technical decisions.
- **Phase B, `approvals.goalPrompt` / `approvals.plan`** → auto.
- **Phase D, review iteration cap exceeded** → PARK the feature: see review-protocol "Unattended". Never merge a PR that reviewers did not approve.
- **Phase E, `approvals.merge`** → auto-merge approved feature PRs into the RUN branch only.
- **Run end, `approvals.runMerge`** → never merge into `git.baseBranch`; the run PR is left open with a summary comment. Single-feature mode likewise: its PR targets the base branch, so it is left open, never auto-merged.
- **Phase E, risky rebase conflict / tests failing after rebase and one fix attempt** → park the feature the same way; continue with the rest.
- **Goal ambiguity** → never write goal.md; interpret conservatively (prefer the literal Success Criteria) and note the ambiguity in the report.

Parked features: leave the branch and open PR intact, post a `gh pr comment` in `config.language` explaining what blocks it, set feature status `abandoned` in state.json, and set the underlying todos to `blocked` with a note referencing the PR — `blocked` items are not re-selected in later iterations, which prevents an unattended loop from endlessly recreating the same stuck feature.
