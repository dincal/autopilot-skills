# Review Protocol — per-PR review orchestration

Reviews exist to catch REAL problems, not to gatekeep. Review is NEUTRAL and evidence-based: a substantiated defect blocks regardless of how much work it invalidates; an unsubstantiated concern never blocks. Reviewing for the sake of rejection is forbidden — a PR without substantiated defects must get approved and merged. You (the orchestrator) enforce this standard structurally.

**Branch-doc writes live on the feature branch.** The branch doc is committed on its feature branch inside that feature's worktree (loop-protocol Phase C) — the main checkout has NO copy, so never edit `.autopilot/branch/<doc>.md` there. Every write this protocol makes to it (a Review Log line per round, a downgrade → Autonomous Decisions, a status correction) is edited in the worktree and committed + pushed on the feature branch (`git -C <worktree> commit` + `push`), and ONLY between agent runs — the reviewers/fix agent have returned, never while one is working that worktree. Commit + push each round's Review Log line the moment you record it (round-structure step 3 below), so the worktree is clean whether you then re-spawn a fix agent or proceed to merge. This is what makes the review history ride the PR and survive the Phase E rebase / worktree removal.

## Round structure

For each PR, run review rounds until both reviewers APPROVE or the cap is hit:

1. Spawn in parallel (background, per PR):
   - `autopilot:code-reviewer` — unless `review.codeReview` is false. Input: REVIEW INPUT block (schemas.md) with PR number, repo path, Goal Prompt, acceptance criteria, `scope: critical-only` when `fastMode`.
   - `autopilot:e2e-tester` — unless `review.e2eTest` is false or `fastMode` is true. Input: worktree path, e2e run settings from config, acceptance criteria.
   - When `review.reviewerModel` is set, spawn BOTH reviewers with that model override (Agent tool `model` option). Running reviewers on a different model than the developer agent decorrelates blind spots; it does not equal an external human review.
   - Record the reviewer task ids in that feature's `features[].agentTask` (state.json) before ending the turn to wait, and clear the field when both verdicts are parsed — this is what lets the keep-alive Stop hook distinguish legitimate waiting from a silent stall.
2. Parse each agent's trailing `VERDICT` block (contract in schemas.md). A missing/malformed VERDICT block → re-spawn that reviewer once; if still malformed, treat as APPROVE with a logged warning (a broken reviewer must not block shipping).
3. Post each reviewer's findings to the PR as a COMMENT: `gh pr comment <n> --body ...` (in `config.language`), starting with a bold verdict line — e.g. `**[code-review r1] VERDICT: REQUEST_CHANGES**` — followed by the BLOCKING/NOTES content. NEVER use `gh pr review --approve/--request-changes`: the PR author and the gh session are the same account, and GitHub rejects reviewing your own PR. Approval state lives with the orchestrator — `features[].reviewRounds` + feature `status` in state.json and the branch doc's Review Log are the source of truth, not GitHub review status. Also append one line to the Review Log, then commit + push that branch-doc write on the feature branch (`git -C <worktree>` add/commit/push). Do this EVERY round, including the final approving round (the reviewers have returned, so the worktree is quiescent) — an uncommitted Review Log line is discarded at Phase E worktree removal and its history never reaches the run branch.

## Both approve → done

The approving round's Review Log line was committed + pushed in round-structure step 3, so the merged doc carries the full review history. Set feature `status: approved`; proceed to merge (loop-protocol Phase E).

## Any REQUEST_CHANGES → fix cycle

1. Union the BLOCKING items from both reviewers, numbered. Contradictory feedback between reviewers: prefer runtime evidence (the e2e-tester ran the actual app; the code-reviewer read code). You may downgrade a code-review BLOCKING item to a note when the e2e evidence shows the behavior works — log the one-line justification in the Review Log, and add the downgrade to the PR body's top "decisions made without user approval" section (`gh pr edit --body`) and the branch doc's Autonomous Decisions.
2. NOTES are never acted on in the fix cycle and never justify another round. Carry them into the branch doc for posterity only.
3. Make sure the round's branch-doc writes are committed + pushed (the Review Log line from step 3, plus any downgrade/NOTES entries from steps 1–2) so the worktree is clean before the agent takes it. THEN re-spawn `autopilot:feature-dev` in the SAME worktree with the standard input block plus a `REVIEW FIXES` section listing only the numbered blocking items. The agent fixes exactly those, re-runs tests, commits.
4. Push the agent's fixes, then start the next round. From round 2 onward, reviewers verify ONLY the previous blocking items plus any regression they introduce — instruct this via the input block (`previous-blocking:` list). No new whole-PR nitpick sweeps.

## Iteration cap

After `review.maxReviewIterations` rounds without dual approval, STOP iterating and escalate to the user (AskUserQuestion):

- **Merge anyway** — record the override in the Review Log, proceed to merge.
- **Keep iterating** — one more batch of rounds (same cap again).
- **Abandon feature** — close the PR (`gh pr close`); the branch doc was pre-marked `merged` at PR creation, so correct its status to `abandoned`; todos back to `pending` with a note.
- **Pause autopilot** — leave the PR open, write state, stop the run cleanly.

**Unattended (`unattended: true`)**: do not ask — PARK the feature instead. Leave the PR open, post a `gh pr comment` (in `config.language`) summarizing the unresolved blocking items and that it needs human review, set feature status `abandoned`, set its todos to `blocked` with a note referencing the PR, and continue the loop with the other features. The parked PR stays open, so its branch doc keeps the pre-marked `merged` status until the PR's fate is resolved (`/autopilot-sync` corrects it to `abandoned` only if the PR is later closed unmerged). Never "merge anyway" without a human.

## Anti-nitpick guardrails (enforced by YOU)

- A BLOCKING item is valid only if it cites the blocking whitelist: incorrect behavior/bug, security or data-loss risk, failing or missing tests for the feature's core path, acceptance criteria demonstrably unmet, or breakage of existing functionality. A blocking item without a whitelist justification is downgraded to a note — log it.
- Style, naming, structure preferences, "could be simpler", hypothetical edge cases without a repro, and missing tests for non-core paths are NEVER blocking.
- Reviews may not expand scope: "while you're at it, also build X" is a new todo item (`source: agent`), not review feedback.
