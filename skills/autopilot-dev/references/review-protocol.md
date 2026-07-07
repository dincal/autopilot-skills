# Review Protocol — per-PR review orchestration

Reviews exist to catch REAL problems, not to gatekeep. The system is approve-biased by design: a PR without genuine defects must get approved and merged. You (the orchestrator) enforce that bias structurally.

## Round structure

For each PR, run review rounds until both reviewers APPROVE or the cap is hit:

1. Spawn in parallel (background, per PR):
   - `autopilot:code-reviewer` — unless `review.codeReview` is false. Input: REVIEW INPUT block (schemas.md) with PR number, repo path, Goal Prompt, acceptance criteria, `scope: critical-only` when `fastMode`.
   - `autopilot:e2e-tester` — unless `review.e2eTest` is false or `fastMode` is true. Input: worktree path, e2e run settings from config, acceptance criteria.
2. Parse each agent's trailing `VERDICT` block (contract in schemas.md). A missing/malformed VERDICT block → re-spawn that reviewer once; if still malformed, treat as APPROVE with a logged warning (a broken reviewer must not block shipping).
3. Post each review to the PR: `gh pr review <n> --approve` or `--request-changes`, `--body` containing the reviewer's findings (in `config.language`). Also append one line per round to the branch doc's Review Log.

## Both approve → done

Feature `status: approved`; proceed to merge (loop-protocol Phase E).

## Any REQUEST_CHANGES → fix cycle

1. Union the BLOCKING items from both reviewers, numbered. Contradictory feedback between reviewers: prefer runtime evidence (the e2e-tester ran the actual app; the code-reviewer read code). You may downgrade a code-review BLOCKING item to a note when the e2e evidence shows the behavior works — log the one-line justification in the Review Log, and add the downgrade to the PR body's top "decisions made without user approval" section (`gh pr edit --body`) and the branch doc's Autonomous Decisions.
2. NOTES are never acted on in the fix cycle and never justify another round. Carry them into the branch doc for posterity only.
3. Re-spawn `autopilot:feature-dev` in the SAME worktree with the standard input block plus a `REVIEW FIXES` section listing only the numbered blocking items. The agent fixes exactly those, re-runs tests, commits.
4. Push, then start the next round. From round 2 onward, reviewers verify ONLY the previous blocking items plus any regression they introduce — instruct this via the input block (`previous-blocking:` list). No new whole-PR nitpick sweeps.

## Iteration cap

After `review.maxReviewIterations` rounds without dual approval, STOP iterating and escalate to the user (AskUserQuestion):

- **Merge anyway** — record the override in the Review Log, proceed to merge.
- **Keep iterating** — one more batch of rounds (same cap again).
- **Abandon feature** — close the PR (`gh pr close`), branch doc `status: abandoned`, todos back to `pending` with a note.
- **Pause autopilot** — leave the PR open, write state, stop the run cleanly.

**Unattended (`unattended: true`)**: do not ask — PARK the feature instead. Leave the PR open, post a `gh pr comment` (in `config.language`) summarizing the unresolved blocking items and that it needs human review, set feature status `abandoned`, set its todos to `blocked` with a note referencing the PR, and continue the loop with the other features. Never "merge anyway" without a human.

## Anti-nitpick guardrails (enforced by YOU)

- A BLOCKING item is valid only if it cites the blocking whitelist: incorrect behavior/bug, security or data-loss risk, failing or missing tests for the feature's core path, acceptance criteria demonstrably unmet, or breakage of existing functionality. A blocking item without a whitelist justification is downgraded to a note — log it.
- Style, naming, structure preferences, "could be simpler", hypothetical edge cases without a repro, and missing tests for non-core paths are NEVER blocking.
- Reviews may not expand scope: "while you're at it, also build X" is a new todo item (`source: agent`), not review feedback.
