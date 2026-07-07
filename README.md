# Autopilot

A Claude Code plugin for goal-driven autonomous development. You set the goal; autopilot keeps the project's living documents in sync and runs a develop → review → merge loop until the goal is met or you say stop.

- Maintains `CLAUDE.md` and a `.autopilot/` document set (goal, design, todo, per-branch docs, changelog) as the project's source of truth
- Develops **N features in parallel**, each in its own git worktree with a background agent
- Ships **one PR per feature**, reviewed by a dedicated code-review agent and an E2E-test agent that actually runs the app
- Approve-biased reviews: blocks only for real defects, never for nitpicks
- Approval gates (goal prompt / plan / merge) configurable between `ask` and `auto`

## Requirements

- Claude Code v2.1+
- A git repository with a **GitHub remote** and an authenticated **`gh` CLI** (the dev loop creates and merges real PRs; it refuses to run without GitHub)
- `python3` on PATH (used by the goal.md write-guard hook)
- Recommended for web projects: a browser MCP server (chrome-devtools or playwright) so the E2E agent can drive the UI; without one it degrades to HTTP-level checks

## Install

From the marketplace repo:

```
/plugin marketplace add dincal/autopilot-skills
/plugin install autopilot@autopilot-marketplace
```

Local development:

```bash
claude --plugin-dir /path/to/autopilot-skills
```

## Usage

| Command | What it does |
|---|---|
| `/autopilot-init [github-repo]` | Initialize `.autopilot/` (config, goal, design, todo, changelog, branch docs) and the managed CLAUDE.md section. With a repo argument (`owner/repo` or URL): wires it up as `origin` — cloning/connecting if it exists on GitHub, creating it via `gh` if it doesn't |
| `/autopilot-goal [guidance]` | Interview you about the project's ultimate and short-term goals, then write `goal.md` — only with your explicit approval |
| `/autopilot-todo [ideas]` | Interview you about features you want and add them to `todo.md` as user-sourced items (top selection rank) |
| `/autopilot-sync` | Reconcile every autopilot file with the current repo reality (code, git history, merged PRs) |
| Say **"develop with autopilot"** / **"오토파일럿으로 개발해"** | Start the autonomous dev loop (a skill, not a slash command) |

Typical flow: `/autopilot-init` → `/autopilot-goal` → "develop with autopilot" → watch PRs land; say "stop" to end the loop. Say "develop *this feature* with autopilot" for a one-shot single-feature run.

## The dev loop

Each iteration:

1. **Select** — refresh `todo.md` against `goal.md`, including running the app to find gaps toward the Success Criteria; pick the next N features (user-entered todos always outrank agent-generated ones; small todos get merged into user-story-sized features)
2. **Plan** — per feature: frame design decisions for you when needed, write a Goal Prompt and an implementation Plan (each gated by `approvals.*`)
3. **Develop** — per feature: branch + worktree + background feature-dev agent; tests are mandatory
4. **Ship & review** — push, `gh pr create`; code-reviewer and e2e-tester agents review in parallel; fix cycles run until both approve (capped by `review.maxReviewIterations`, then escalated to you)
5. **Merge & close** — merge per `approvals.merge` (sequential, with rebases in between), update todo/changelog/branch docs/CLAUDE.md, clean up worktrees
6. Repeat — until you stop it, `loop.maxIterations` hits, or every Success Criterion in `goal.md` is verifiably met

## Configuration (`.autopilot/config.json`)

Created by `/autopilot-init`; JSON Schema in [`templates/config.schema.json`](templates/config.schema.json). Key settings:

| Setting | Default | Meaning |
|---|---|---|
| `mode` | `loop` | `loop` (repeat until stopped) or `single-feature` (one feature, no loop, no worktrees) |
| `fastMode` | `false` | Minimize review: skip E2E, one review round, critical defects only |
| `parallelFeatures` | `2` | Features developed concurrently per iteration (1–4) |
| `approvals.goalPrompt` / `.plan` / `.merge` | `ask` | `ask` pauses for your approval; `auto` proceeds |
| `approvals.newTodos` | `auto` | Gate for agent-generated todo items |
| `review.maxReviewIterations` | `3` | Fix-and-re-review cycles before escalating to you |
| `testing.requireTests` | `true` | Every feature must ship with tests |
| `git.baseBranch` / `.branchPrefix` / `.mergeMethod` | `main` / `autopilot/` / `squash` | Git/PR policy |
| `language` | `ko` | Language of generated documents and PR bodies (code/commits/PR titles are always English) |

## Guarantees

- **`goal.md` is yours.** Agents can never write it without your explicit approval: every skill and agent is instructed not to, and a `PreToolUse` hook hard-denies writes unless `/autopilot-goal` has just obtained your consent (one-shot token, 15-minute validity).
- **Your CLAUDE.md text is safe.** Autopilot only regenerates the section between `<!-- AUTOPILOT:BEGIN -->` and `<!-- AUTOPILOT:END -->` markers.
- **`todo.md` reflects only unbuilt work**, and your items always outrank the agent's.
- **Nothing merges with failing tests**, and nothing ships without review unless you configured it that way.

## Repository layout

```
.claude-plugin/     plugin.json, marketplace.json
skills/             autopilot-goal, autopilot-init, autopilot-todo, autopilot-sync (slash commands)
                    autopilot-dev (model-invoked loop) + references/ protocols
agents/             feature-dev, code-reviewer, e2e-tester
hooks/              goal.md write guard (PreToolUse)
templates/          config schema/defaults and document templates
```
