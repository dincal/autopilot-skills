# Autopilot

> 한국어 사용설명서: [README.ko.md](README.ko.md)

A Claude Code plugin for goal-driven autonomous development. You set the goal; autopilot keeps the project's living documents in sync and runs a develop → review → merge loop until the goal is met or you say stop.

- Maintains `CLAUDE.md` and a `.autopilot/` document set (goal, design, todo, per-branch docs, changelog) as the project's source of truth
- Develops **N features in parallel**, each in its own git worktree with a background agent
- Ships **one PR per feature**, reviewed by a dedicated code-review agent and an E2E-test agent that actually runs the app
- Neutral, evidence-based reviews: substantiated defects block, nitpicks never do — reviewing to reject is forbidden
- Approval gates (goal prompt / plan / merge) configurable between `ask` and `auto`

## Requirements

- Claude Code v2.1+
- A git repository with a **GitHub remote** and an authenticated **`gh` CLI** (the dev loop creates and merges real PRs; it refuses to run without GitHub)
- `python3` on PATH (used by the goal.md write-guard hook)
- Recommended: the **Claude Design MCP** for `/autopilot-design` and in-loop design decisions — `claude mcp add --scope user --transport http claude-design https://api.anthropic.com/v1/design/mcp`, then `/design-login` (Pro/Max/Team/Enterprise)
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
| `/autopilot-init [github-repo] [overview]` | Initialize `.autopilot/` (config, goal, design, todo, changelog, branch docs) and the managed CLAUDE.md section. With a repo argument (`owner/repo` or URL): wires it up as `origin` — cloning/connecting if it exists on GitHub, creating it via `gh` if it doesn't. Remaining argument text becomes the project overview (asked interactively when it can't be derived) |
| `/autopilot-goal [guidance]` | Interview you about the project's ultimate and short-term goals, then write `goal.md` — only with your explicit approval |
| `/autopilot-todo [ideas]` | Interview you about features you want and add them to `todo.md` as user-sourced items (top selection rank) |
| `/autopilot-config [change]` | Show current settings and update `config.json` through an interview (validated against the schema) |
| `/autopilot-project-review` | Coldly assess how the market would react to launching this project (no cheerleading — base rates, competitors, ranked risks), then update `goal.md`/`todo.md` through an interview |
| `/autopilot-design [hints]` | Audit the current look & feel, interview you, then iterate real mockups in **Claude Design** (project created/reused automatically) until you approve them; only then writes `design.md`'s living Style Guide — enforced on every future UI feature's Goal Prompt |
| `/autopilot-dev-run [stop\|restart\|status]` | Run the project's dev server as a managed background process — a `PostToolUse` hook restarts it automatically after every `gh pr merge` / `git pull` in a session, so merged autopilot features are always live |
| `/autopilot-stop` | Conclude the current run: settle in-flight features (merge/park/abandon, your call), finalize the run PR into the base branch, and merge it once you approve |
| `/autopilot-sync` | Reconcile every autopilot file with the current repo reality (code, git history, merged PRs) |
| Say **"develop with autopilot"** / **"오토파일럿으로 개발해"** | Start the autonomous dev loop (a skill, not a slash command) |

Typical flow: `/autopilot-init` → `/autopilot-goal` → "develop with autopilot" → watch PRs land; say "stop" to end the loop. Say "develop *this feature* with autopilot" for a one-shot single-feature run.

## The dev loop

Each iteration:

1. **Select** — refresh `todo.md` against `goal.md`, including running the app to find gaps toward the Success Criteria; pick the next N features (user-entered todos always outrank agent-generated ones; small todos get merged into user-story-sized features)
2. **Plan** — per feature: frame design decisions for you when needed, write a Goal Prompt and an implementation Plan (each gated by `approvals.*`)
3. **Develop** — per feature: branch + worktree + background feature-dev agent; tests are mandatory
4. **Ship & review** — push, `gh pr create`; code-reviewer and e2e-tester agents review in parallel; fix cycles run until both approve (capped by `review.maxReviewIterations`, then escalated to you)
5. **Merge & close** — feature PRs merge into the **run branch** per `approvals.merge` (sequential, with rebases in between); docs update on the run branch; worktrees cleaned up
6. Repeat — until you stop it, `loop.maxIterations` hits, or every Success Criterion in `goal.md` is verifiably met. At run end, one **run PR** (run branch → base) carries everything into your base branch, gated by `approvals.runMerge`

Each run gets its own run branch (`autopilot/run-<id>`) forked from your base branch — features stack on it, and your base branch is only touched by the final run PR.

## Configuration (`.autopilot/config.json`)

Created by `/autopilot-init`; JSON Schema in [`templates/config.schema.json`](templates/config.schema.json). Key settings:

| Setting | Default | Meaning |
|---|---|---|
| `mode` | `loop` | `loop` (repeat until stopped) or `single-feature` (one feature, no loop, no worktrees) |
| `fastMode` | `false` | Minimize review: skip E2E, one review round, critical defects only |
| `unattended` | `false` | The dev loop never asks you anything: gates behave as `auto`, decision points use documented safe defaults, stuck features get parked (PR left open with a comment) instead of force-merged. goal.md still requires your consent |
| `ultracode` | `false` | Multi-agent Workflow orchestration inside the loop: fan-out gap analysis, multi-plan judging, adversarially verified review. Needs the Workflow tool (falls back gracefully); costs significantly more tokens |
| `parallelFeatures` | `2` | Features developed concurrently per iteration (1–4) |
| `approvals.goalPrompt` / `.plan` / `.merge` | `ask` | `ask` pauses for your approval; `auto` proceeds (`.merge` covers feature PRs → run branch) |
| `approvals.runMerge` | `ask` | Gate for the final run PR into your base branch. Unattended runs never merge it regardless — the PR waits for you |
| `approvals.newTodos` | `auto` | Gate for agent-generated todo items |
| `review.maxReviewIterations` | `3` | Fix-and-re-review cycles before escalating to you |
| `review.reviewerModel` | `null` | Run review agents on a different model than the developer agent to decorrelate blind spots (e.g. `opus`); `null` inherits the session model |
| `testing.requireTests` | `true` | Every feature must ship with tests (acceptance criteria + edge cases + error paths) |
| `testing.coverage.target` | `80` | Minimum coverage (%) for changed code — feature agents keep adding tests until met when coverage is measurable (`testing.coverage.command`) |
| `devRun.autoStart` | `true` | Auto-start the managed dev server at run start (when the project is runnable and none is alive) — merged features go live automatically |
| `git.baseBranch` / `.branchPrefix` / `.mergeMethod` | `main` / `autopilot/` / `rebase` | Git/PR policy |
| `language` | `ko` | Language of generated documents and PR bodies (code/commits/PR titles are always English) |

## Guarantees

- **`goal.md` is yours.** Agents can never write it without your explicit approval — even in unattended mode: every skill and agent is instructed not to, and a `PreToolUse` hook hard-denies writes unless `/autopilot-goal` has just obtained your consent (one-shot token, 15-minute validity).
- **Your CLAUDE.md text is safe.** Autopilot only regenerates the section between `<!-- AUTOPILOT:BEGIN -->` and `<!-- AUTOPILOT:END -->` markers.
- **Every PR confesses first.** The PR body always leads with a highlighted "decisions made without user approval" section — design choices, auto-passed gates, plan deviations, review-arbitration overrides — followed by the work summary, so you can audit what was decided for you before merging.
- **`todo.md` reflects only unbuilt work**, and your items always outrank the agent's.
- **Your base branch is insulated.** Features merge into a per-run branch; only the final run PR touches base, and unattended runs never merge it — it stays open until you do.
- **The loop can't die silently.** A `Stop` hook blocks the orchestrator from ending its turn while a run is active and bounces it back into the loop; stopping requires finishing the run-end protocol or explicitly pausing. Waiting on background agents is exempt (recorded task ids in state.json let the turn end; the harness re-invokes on completion), and a progress-aware cap (3 nudges without progress) lets a genuinely stuck run stop for later resume.
- **Nothing merges with failing tests**, and nothing ships without review unless you configured it that way.

## Repository layout

```
.claude-plugin/     plugin.json, marketplace.json
skills/             autopilot-goal, autopilot-init, autopilot-todo, autopilot-config,
                    autopilot-project-review, autopilot-sync (slash commands)
                    autopilot-dev (model-invoked loop) + references/ protocols
agents/             feature-dev, code-reviewer, e2e-tester
hooks/              goal.md write guard (PreToolUse)
templates/          config schema/defaults and document templates
```
