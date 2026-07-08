# Worktree Protocol — parallel feature development mechanics

## Locations

- Worktree root: `git.worktreeRoot` from config; when null, use the sibling directory `<repo-parent>/<repoName>__autopilot/`. NEVER place worktrees inside the repository (they would pollute the main session's searches).
- One worktree per feature: `<worktreeRoot>/<branch-slug>/`.
- Record the absolute worktree path in `state.json` for every feature — cleanup must never depend on guessing paths.

## Create

For each feature (from a clean, up-to-date base):

```bash
git fetch origin
mkdir -p <worktreeRoot>
git worktree add <worktreeRoot>/<slug> -b <branch> origin/<run branch>
```

Feature branches always fork from the RUN branch (created at run setup — see loop-protocol), never from `git.baseBranch` directly.

Then prepare the worktree so the agent can work immediately: install dependencies if the project needs it (`npm ci`, `uv sync`, etc. — detect from lockfiles), and verify the test command runs there.

Why explicit worktrees (not the Agent tool's built-in worktree isolation): the loop needs deterministic branch names for PRs, state.json tracking, rebases after sequential merges, and post-merge cleanup.

## Spawn

Spawn one `autopilot:feature-dev` agent per feature with the Agent tool:

- `subagent_type`: `autopilot:feature-dev`
- `run_in_background`: true
- `prompt`: the FEATURE INPUT block defined in `schemas.md`, fully self-contained (the agent has no access to your conversation): feature id, worktree absolute path, branch name, Goal Prompt, Plan, test command, doc language, and the REVIEW FIXES block when re-spawning for fixes.

Track returned task/agent ids in state.json (`features[].agentTask`). The harness notifies you as each background agent finishes — harvest results as they arrive (pipeline); never block waiting for all N.

## Harvest

From each finished agent, parse the trailing fenced `WORK SUMMARY` block (contract in `schemas.md`). Missing or malformed block, or `tests: failing` → treat the feature as `failed` (see loop-protocol Phase C). Never push or open a PR for a feature whose tests are not green.

## Cleanup

- Normal path (after merge): `git worktree remove <path>` then `git worktree prune`; delete the local branch if `git.deleteBranchAfterMerge` (the remote branch is deleted by `gh pr merge --delete-branch` / the repo's delete-branch-on-merge setting).
- Abandoned/failed features: same removal; keep the branch doc with final status for the audit trail; return todos to `pending`. If the branch was pushed, delete the REMOTE branch too (`git push origin --delete <branch>`) — except for parked features and "keep the branch" choices, which intentionally leave the branch and PR for a human.
- If removal fails due to stray untracked files, use `git worktree remove --force` — but only for paths registered in state.json.
- Preflight of every run: reconcile `git worktree list` against state.json; worktrees under the worktree root that no live feature owns are orphans — offer removal to the user.

## Concurrency cautions

- All `.autopilot/` doc writes (todo.md, state.json, branch docs, CHANGELOG) happen ONLY in the main checkout by you, the orchestrator — never by feature agents. This is what prevents write races; do not violate it.
- Feature agents never push and never touch `gh` — pushing and PR creation stay with the orchestrator, in one place.
- Dependencies between concurrent features are a planning error; if you discover one mid-flight, finish the independent one, merge it, then rebase the dependent one before its review.
