# Schemas — file formats and agent I/O contracts

## .autopilot/state.json (runtime, gitignored)

Rewritten atomically (full file) at every phase transition.

```json
{
  "schemaVersion": 1,
  "run": {
    "id": "run-<YYYYMMDD>-<HHmm>",
    "branch": "autopilot/run-20260707-1530",
    "pr": null,
    "previousBranch": "main",
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

- `run.phase`: `idle | paused | selecting | planning | developing | reviewing | merging | docs` — `idle`: no run / run finished; `paused`: run suspended mid-flight (resumable). A plugin Stop hook blocks the orchestrator from ending its turn while the phase is anything else, so phase transitions are what legitimately stop the loop.
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
- coverage-target: 80            <!-- from testing.coverage.target; omit when null -->
- coverage-command: npm test -- --coverage   <!-- from testing.coverage.command; omit when unknown -->
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
- coverage: <measured % for the changed code, or "not measured — <why>">
- files-changed:
  - path — one-line what/why
- tests-added:
  - path — what it proves
- how-to-verify: <steps a human can follow>
- deviations-from-plan: <or "none">
- autonomous-decisions: <choices made that the user might have wanted to decide — UX behavior, naming, data formats, added dependencies, trade-offs — or "none">
- open-questions: <or "none">
```

`tests: failing` or a missing block → the orchestrator treats the feature as failed. Never open a PR for it.

## PR body (orchestrator → `gh pr create`)

Written in `config.language`. The body MUST begin with these two sections, in this order, before anything else:

```markdown
## ⚠️ 사용자 동의 없이 임의로 결정한 사항
<!-- section title localized to config.language; keep the ⚠️ and keep it FIRST -->
- <decision> — <why the agent chose it, and what a user might have preferred to weigh in on>
- ...
(when every decision was explicitly user-approved: "없음 — 모든 결정이 사용자 승인을 거침")

## 작업 요약
<!-- work summary, localized -->
- <what was built, at acceptance-criteria level>
```

Compile the decisions section from ALL of:

- approval gates that ran as `auto` (including unattended runs): state plainly that the Goal Prompt and/or Plan were never user-reviewed, and surface their key choices
- design decisions recorded in design.md as `Decided by: agent ...`
- the WORK SUMMARY's `autonomous-decisions` and `deviations-from-plan` entries
- review arbitration: blocking items the orchestrator downgraded to notes

After these two sections, append: acceptance-criteria checklist, test evidence (including measured coverage when available), how to verify, and references (feature id, AP-### todos, branch doc).

If later review rounds add autonomous decisions (e.g. arbitration downgrades), update the PR body's top section via `gh pr edit --body` so it stays complete at merge time.

## Run PR body (run branch → `git.baseBranch`)

Same leading structure — the ⚠️ decisions section FIRST, aggregating the autonomous decisions of every feature in the run — then the run summary: iterations completed, merged feature PRs (links + one-liners), parked/failed features, todo & changelog updates, aggregate test/coverage evidence. Kept current with `gh pr edit` each iteration and finalized at run end.

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

Branch `autopilot/ap-012-price-filter` → file `autopilot--ap-012-price-filter.md` (every `/` → `--`). Sections: metadata list (created/base/features/pr/status), `## Goal Prompt`, `## Plan`, `## Autonomous Decisions` (mirrors the PR body's top section), `## Work Summary`, `## Review Log`. Status: `in-progress | in-review | merged | abandoned`. Serves as the PR body source and audit trail; archived to `branch/archive/` after merge by `/autopilot-sync`.

## CHANGELOG.md entry

Under `## [Unreleased]`, grouped Keep-a-Changelog style (`### Added/Changed/Fixed/Removed`):

```markdown
- Filter products by price (AP-012, PR #42)
```
