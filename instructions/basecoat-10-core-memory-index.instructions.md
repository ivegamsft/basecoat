---
description: "L2 memory index. Loads at session start to prime fast pattern recall. Maps trigger contexts to known high-confidence patterns and subject tags for deeper retrieval. Keep under 500 tokens — index only, no full memories."
applyTo: "**/*"
distribute: false
---

# Memory Index — L2 Hot Cache

> **For forks of BaseCoat:** Replace the Trigger Map and Pattern Bundle Catalog with your team's patterns. Keep Memory Hierarchy and routing sections — they are framework guidance. Accumulated memories (SQLite store, session state) are git-ignored and never travel upstream.

This file is the L2 tier of the BaseCoat memory hierarchy. It loads at session start to prime fast recall before any task begins.

**Rule:** Do not inline full memories here. One line per pattern + subject tag. Full retrieval goes to L3/L4.

## Memory Hierarchy

| Tier | Name | Mechanism | Lookup cost |
|---|---|---|---|
| L0 | Reflexes | Hard rules in frontmatter + always-on instructions | Zero — baked in |
| L1 | Procedural | `applyTo: **/*` instruction files | Zero — always loaded |
| L2 | Team Hot Index | This file — trigger → pattern/subject map | ~400 tokens at session start |
| L2s | Shared Hot Index | `{org}/basecoat-memory/hot-index.md` (if configured) | ~400 tokens at session start |
| L3 | Episodic | `session_store_sql` — recent session history | 1 tool call, ~200–500 tokens |
| L3s | Shared Deep | `memories/{domain}/*.md` from shared repo (cached) | On demand, per domain |
| L4 | Semantic | `store_memory` recall + `docs/` reference | 1–2 tool calls, load on demand |

### Promotion Ladder (Summary)

Patterns promote through heat score — move up when `heat ≥ threshold` sustained across sessions; demote when heat drops below floor after inactivity. Mark pinned patterns `[pin]` to exempt from decay.

See [`references/memory-index/memory-algorithms.md`](references/memory-index/memory-algorithms.md) for full formulas.

## Intent Classification — TRM Two-Pass Routing

1. **Pass 1:** Match against L2 trigger map; compute initial confidence
2. **Evaluate:** confidence ≥ 0.80 or ≤ 0.30 → converge immediately (skip Pass 2)
3. **Pass 2:** For scores 0.30–0.79, retrieve a targeted L3 snippet (last N=3 turns on topic) and reclassify

Max confidence boost from Pass 2: **+0.15**. For EscalationQuery contract and GuidanceSignal types, see [`references/memory-index/memory-algorithms.md`](references/memory-index/memory-algorithms.md).

## Pattern Bundles — Fast Path Catalog

| Bundle | Trigger keywords | Turn budget | Confidence |
|---|---|---|---|
| `run-tests` | run tests, validate, check tests | 1 | 0.98 |
| `fix-lint` | lint, MD0xx, fix warnings, markdown lint | 2 | 0.92 |
| `new-agent` | new agent, create agent, add agent | 3 | 0.88 |
| `new-instruction` | new instruction, add instruction | 2 | 0.90 |
| `compile-aw` | compile, agentic workflow, gh aw compile | 2 | 0.90 |
| `merge-pr` | merge PR, dependabot, merge pull request | 3 | 0.85 |
| `release` | release, version bump, tag, CHANGELOG | 4 | 0.87 |
| `clean-branches` | clean branches, stale branches, delete merged | 2 | 0.95 |
| `portal-feature` | portal, component, hook, frontend | 5 | 0.80 |
| `contribute-memory` | contribute memory, export memory, push to memory repo, sprint end | 2 | 0.90 |

Confidence is updated using Bayesian incremental learning after each outcome. Security/governance bundles marked `[pin]` are exempt from decay. See [`references/memory-index/memory-algorithms.md`](references/memory-index/memory-algorithms.md) for the update formula.

### CI / GitHub Actions

| Trigger | Pattern | Subject |
|---|---|---|
| Edit agentic workflow | `add-labels` and `add-comment` take no sub-properties; `allowed-labels` belongs under `create-issue` | `gh-aw` |
| gh aw expressions | Allowed: `issue.number/title`, `pull_request.number/title`, `workflow_run.id/conclusion/head_sha`, `repository`, `run_number`, `actor` — fetch body/login via `gh` CLI | `gh-aw` |
| gh aw compile | Markdown body edits don't require recompile; frontmatter changes do. Run `gh aw compile <name>` | `gh-aw` |
| `workflow_run` trigger | Add `types: [completed]`; check `conclusion == 'failure'` in body | `ci-workflow` |
| Copilot agent PR | Shows `action_required` (0 jobs) — maintainer must push empty commit to trigger CI | `ci-approval` [pin] |

### Testing

| Trigger | Pattern | Subject |
|---|---|---|
| Full validation | `pwsh tests/run-tests.ps1` — runs all tests including lint and agent checks | `testing-commands` |
| Structure only | `pwsh scripts/validate-basecoat.ps1` — asset structure check without full suite | `asset-validation` |

### Authoring Assets

| Trigger | Pattern | Subject |
|---|---|---|
| New agent file | Must have `## Inputs`, `## Workflow` (or `## Process`), and output section — validated by test suite | `agent-conventions` [pin] |
| New skill | `SKILL.md` needs `name` + `description` frontmatter; `allowed_skills` must match directory name exactly | `skill-conventions` [pin] |
| Markdown lint | `##` headings only (MD036), blank lines before/after code fences (MD031), files end with newline (MD047) | `markdown-standards` |

### Portal

| Trigger | Pattern | Subject |
|---|---|---|
| Scan polling | `useScanPoller(scanId, 3000, 20)` — stops on `completed`/`failed` or maxAttempts | `portal-scan` |
| Scan backend | POST `/scans` sets `status: 'running'`; setTimeout stub → `completed` after 5s | `portal-backend` |

### Git / Branches

| Trigger | Pattern | Subject |
|---|---|---|
| Branch cleanup | Squash merges won't show as `--merged`; use `gh pr list --state all --head <branch>` to verify | `git-hygiene` |
| Worktrees | Sprint branches use separate worktrees; check with `git worktree list` | `git-worktree` |

### Turn Budget

| Trigger | Pattern | Subject |
|---|---|---|
| Starting any task | Classify Routine(≤3 turns) / Familiar(≤5) / Novel(estimate N) before starting | `turn-budget` [pin] |
| Stuck after 5 turns | `store_memory` failure pattern, change approach, do not escalate model tier first | `failure-protocol` [pin] |
| Task succeeds with novel solution | `store_memory` if non-obvious pattern + tests pass; skip for boilerplate | `success-protocol` |

## HRM Tier Resolution Order

Resolve memory tier by tier — do not skip layers or query deeper tiers before shallower ones:

| Tier | Resolves | Escalates when |
|------|---------|----------------|
| L0/L1 | Always-on rules; glob-scoped instructions | Out-of-scope for the glob or hard rule |
| L2 | Pattern bundle match, confidence ≥ 0.80 | Confidence < 0.80 after TRM Pass 2 |
| L3 | Prior session coverage of the task | No matching session found |
| L4 | Long-term fact or architecture guidance | No coverage → generate and store |

## Memory Scope Checklist

Before calling `store_memory`, validate all four:

1. **Repo-scoped** — Applies to this repo's conventions, not a customer/sub-project
2. **Generic** — Useful to any BaseCoat team, not one company's specific setup
3. **Durable** — Will still be true in 3+ sprints
4. **Actionable** — Changes what an agent does next

If any answer is "no", skip `store_memory`. Document in `docs/` or keep as session note.

For sharing across sessions/users: see `docs/memory/PROCESS.md` — contribute to `basecoat-memory`.

## References

| Topic | File |
|---|---|
| Promotion ladder formula, TRM confidence math, EscalationQuery contract, confidence update formula | [`references/memory-index/memory-algorithms.md`](references/memory-index/memory-algorithms.md) |
| Full HRM layer definitions, GuidanceSignal types | `instructions/hrm-execution.instructions.md` |
| Reflexion failure signal format, two-pass classification | `instructions/trm-reflexion.instructions.md` |
| TRM estimator rationale and threshold calibration | `docs/research/TRM-HRM-investigation.md` |
| End-to-end memory contribution pipeline, scope policy, steward guide | [`docs/memory/PROCESS.md`](../docs/memory/PROCESS.md) |
