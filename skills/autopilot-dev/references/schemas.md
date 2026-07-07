# Schemas — file formats and agent I/O contracts

## .autopilot/state.json (runtime, gitignored)

Rewritten atomically (full file) at every phase transition.

```json
{
  "schemaVersion": 1,
  "run": {
    "id": "run-<YYYYMMDD>-<HHmm>",
    "mode": "loop",
    "fastMode": false,
    "iteration": 3,
    "phase": "developing",
    "startedAt": "<ISO8601>"
  },
  "worktreeRoot": "/abs/path/<repoName>__autopilot",
  "features": [
    {
      "id": "F-2026-07-07-a",
      "todos": ["AP-012"],
      "branch": "autopilot/ap-012-price-filter",
      "worktree": "/abs/path/<repoName>__autopilot/ap-012-price-filter",
      "agentTask": "<background task id or null>",
      "status": "developing",
      "pr": null,
      "reviewRounds": 0
    }
  ],
  "lastSyncCommit": "<sha>"
}
```

- `run.phase`: `idle | selecting | planning | developing | reviewing | merging | docs`
- `features[].status`: `planned | developing | dev-done | in-review | changes-requested | approved | merged | failed | abandoned`

## todo.md item

```markdown
- [ ] AP-012 | P1 | user | pending
  - story: As a shopper, I want to filter products by price so that I can find items in my budget.
  - acceptance:
    - A price filter control appears on the product list page
    - Results update without a full page reload
  - depends-on: AP-009
  - notes: requested on 2026-07-05
```

Rules (also in the file's legend header): ID monotonically increasing, never reused; ordering source(user first) → priority(P0 highest) → ID; story line mandatory (≥ user-story size); acceptance bullets observable (E2E verifies these); status `pending | selected | in-progress | in-review | blocked`; done items are removed, not checked off.

## Goal Prompt (per feature, stored in the branch doc)

```markdown
### Objective
One sentence: what exists when this feature is done.
### User story
As a ..., I want ..., so that ...
### Acceptance criteria
- [ ] observable behavior 1
- [ ] observable behavior 2
### Constraints
Stack, patterns, performance, compatibility constraints that apply.
### Out of scope
What this feature explicitly does NOT include.
```

## FEATURE INPUT block (orchestrator → feature-dev agent)

The spawn prompt must be fully self-contained:

```markdown
# FEATURE INPUT
- feature-id: F-2026-07-07-a
- worktree: /abs/path (work ONLY inside this directory)
- branch: autopilot/ap-012-price-filter (already checked out in the worktree)
- test-command: npm test
- doc-language: ko

## GOAL PROMPT
<verbatim approved Goal Prompt>

## PLAN
<verbatim approved Plan>

## REVIEW FIXES        <!-- only present on fix-cycle re-spawns -->
Fix ONLY these items, then re-run tests:
1. <file:line> — <blocking issue>
```

## WORK SUMMARY block (feature-dev agent → orchestrator)

The agent's final message MUST end with this fenced block:

```markdown
## WORK SUMMARY
- feature-id: F-2026-07-07-a
- tests: passing | failing
- test-evidence: <command run + summary of output>
- files-changed:
  - path — one-line what/why
- tests-added:
  - path — what it proves
- how-to-verify: <steps a human can follow>
- deviations-from-plan: <or "none">
- open-questions: <or "none">
```

`tests: failing` or a missing block → the orchestrator treats the feature as failed. Never open a PR for it.

## REVIEW INPUT block (orchestrator → code-reviewer / e2e-tester)

```markdown
# REVIEW INPUT
- pr: 42                       # code-reviewer
- repo: /abs/path/to/main/checkout
- worktree: /abs/path          # e2e-tester
- run-command: npm run dev     # e2e-tester (plus ready-check / url if configured)
- scope: full | critical-only  # critical-only when fastMode
- round: 1
- previous-blocking:           # rounds ≥ 2 only — verify ONLY these + regressions
  1. <item>
- doc-language: ko

## GOAL PROMPT
<verbatim, including acceptance criteria>
```

## VERDICT block (reviewers → orchestrator)

Each reviewer's final message MUST end with:

```markdown
## VERDICT: APPROVE | REQUEST_CHANGES
BLOCKING:
1. <file:line or repro steps> — <issue> — <which whitelist category and why>
NOTES:
- <non-blocking observations>
```

`BLOCKING:` must be empty when the verdict is APPROVE. Items without a whitelist justification are downgraded to notes by the orchestrator.

## branch/<sanitized>.md

Branch `autopilot/ap-012-price-filter` → file `autopilot--ap-012-price-filter.md` (every `/` → `--`). Sections: metadata list (created/base/features/pr/status), `## Goal Prompt`, `## Plan`, `## Work Summary`, `## Review Log`. Status: `in-progress | in-review | merged | abandoned`. Serves as the PR body source and audit trail; archived to `branch/archive/` after merge by `/autopilot-sync`.

## CHANGELOG.md entry

Under `## [Unreleased]`, grouped Keep-a-Changelog style (`### Added/Changed/Fixed/Removed`):

```markdown
- Filter products by price (AP-012, PR #42)
```
