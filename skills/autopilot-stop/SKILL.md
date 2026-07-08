---
name: autopilot-stop
description: Conclude the current autopilot run — settle every in-flight feature, finalize the run PR into the base branch, and merge it once the user approves.
argument-hint: ""
disable-model-invocation: true
---

# Autopilot Stop

Bring the current autopilot run to a clean conclusion: settle all in-flight features, get the run branch's PR into `git.baseBranch` finalized, and merge it with the user's approval. This is the user-driven counterpart to the loop's automatic Run end — use it after an unattended run (which parks its run PR), after an interrupt/pause, or any time the user wants to ship what autopilot has built so far.

## Step 1 — Load state

Read `.autopilot/state.json` and `.autopilot/config.json`.

- No state.json, or `run.phase: "idle"` with no live run branch → report there is nothing to stop. If a leftover `<branchPrefix>run-*` branch or open run PR exists on origin anyway, offer to conclude that one (treat it as the run below).
- `run.phase` active or `"paused"` → proceed. Cross-check `git worktree list` and open PRs (`gh pr list --head <branchPrefix>*`) against `state.json.features` so you settle reality, not just the recorded state.

## Step 2 — Settle in-flight features

1. Stop any still-running background feature agents recorded in `features[].agentTask`.
2. Then settle each feature by status — ask the user ONCE (AskUserQuestion, one question per unfinished feature, batched) rather than deciding silently:
   - `merged` → nothing to do.
   - `approved` (reviewed, not yet merged) → recommend **Merge into the run branch now**; alternatives: Park (leave PR open) / Abandon (close PR, todos → `pending`).
   - `in-review` / `changes-requested` → **Park** (leave the PR open with a status comment; todos → `blocked` referencing the PR) or **Abandon** (close the PR; todos → `pending` with a note).
   - `developing` / `dev-done` (no PR yet) → **Abandon** (todos → `pending`) or **Keep the branch** (commit & push what exists in the worktree, leave the branch for manual follow-up; todos → `blocked`).
3. Apply the choices: merge approved PRs sequentially into the run branch (rebase remaining ones after each, as in the loop's Phase E), post parking comments, close abandoned PRs, update todo.md statuses and branch-doc final statuses.
4. Remove the worktrees of all settled features; `git worktree prune`.

## Step 3 — Finalize run docs

On the run branch (pull first): make sure merged features are reflected in todo.md (items removed) and CHANGELOG.md (`[Unreleased]` entries), branch docs carry final statuses, and commit any resulting `.autopilot/` updates (`chore(autopilot): conclude run <id>`), then push.

## Step 4 — Run PR

- If the run merged at least one feature: create the run PR (`gh pr create --base <git.baseBranch> --head <run branch>`) if it doesn't exist, then finalize its body per the "Run PR body" schema in `${CLAUDE_PLUGIN_ROOT}/skills/autopilot-dev/references/schemas.md`: cumulative ⚠️ autonomous-decisions section first, then iterations, merged feature PRs, parked/abandoned features, aggregate test/coverage evidence.
- If the run merged nothing: no run PR — offer to delete the run branch (local and origin) and skip to Step 6.

## Step 5 — User approval gate, then merge

Show the run PR link and a one-paragraph summary, then AskUserQuestion:

- **Merge now** → `gh pr merge <run pr> --<git.mergeMethod>` (add `--delete-branch` per `git.deleteBranchAfterMerge`), then update the local base branch (`git pull` after switching in Step 6).
- **Leave the PR open** → keep it for later review; nothing merges.
- **Cancel** → stop here; the run stays concluded but unmerged.

Never merge without the explicit "Merge now" answer — this command exists to put the user in charge of the base branch.

## Step 6 — Close out

1. Restore the main checkout to `state.json.run.previousBranch` (fall back to `git.baseBranch`); pull if the run PR was merged. Restore any stash the run left behind.
2. Set `state.json`: feature statuses final, `run.phase: "idle"`; delete `.autopilot/.stop-guard`. Append the closing entry to the run log.
3. Report: merged feature list, parked/abandoned features with PR links, run PR outcome, which branch the user is now on, and (if things were parked) how to resume them later.
