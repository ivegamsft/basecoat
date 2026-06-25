# Multi-Agent Workflow Guide

How to structure parallel agent work so branches stay mergeable, conflicts stay minimal, and the merge step does not hang.

## The Problem

When multiple agents work in parallel on separate branches, every agent touches overlapping files: `README.md`, `INVENTORY.md`, `CHANGELOG.md`, shared config, shared test fixtures. Without structure, the merge step becomes a manual conflict-resolution marathon — or worse, it silently hangs waiting for an interactive git editor that never gets input.

This guide captures the patterns that work.

---

## The Fresh Clone Principle

> **Always clone fresh. Never reuse a dirty working directory.**

A working directory from a previous agent run may carry:

- Unresolved conflict markers (`<<<<<<< HEAD`)
- A detached HEAD state from an aborted rebase
- Uncommitted changes that corrupt subsequent merges
- Stale remote-tracking refs that hide new commits

The fix is trivial and non-negotiable:

```bash
WORKDIR="/tmp/agent-$(date +%s)"
git clone <repo-url> $WORKDIR
cd $WORKDIR
git fetch --all
```

Clean up after each run:

```bash
cd /tmp && rm -rf $WORKDIR
```

---

## Branch Naming Conventions

Consistent names let tooling (and humans) understand scope and order at a glance.

### Parallel sprint branches

```text
feature/sprint-{N}-{app-or-area}
```

Examples:

```text
feature/sprint-3-api
feature/sprint-3-ui
feature/sprint-3-data
feature/sprint-3-tests
feature/sprint-3-docs
```

- `N` is the sprint number — makes ordering unambiguous
- `app-or-area` is the bounded context the agent owns for this sprint
- Never reuse a branch name across sprints (creates confusing history)

### Hotfix branches

```text
hotfix/{issue-number}-{short-description}
```

### Agent-specific branches (non-sprint)

```text
feature/{issue-number}-{short-description}
```

This is the single-issue pattern used when an agent is working a specific GitHub Issue, not part of a coordinated sprint.

---

## Minimizing Conflicts by Design

### 1. Assign file ownership to agents

Before the sprint starts, decide which agent owns which files. An agent that does not need a file should not touch it.

| File | Owner |
|------|-------|
| `README.md` | docs agent only |
| `INVENTORY.md` | docs agent only |
| `CHANGELOG.md` | release agent only |
| `package.json` / `*.csproj` | one agent per manifest |
| `src/api/**` | backend-dev agent |
| `src/ui/**` | frontend-dev agent |
| `tests/**` | qa agent |

### 2. Avoid shared infrastructure files in every branch

If every branch touches `.gitignore`, `README.md`, and `INVENTORY.md`, every merge has conflicts. Instead:

- Route all shared-file updates to a single designated branch
- Other agents skip those files and file issues requesting the update
- The docs/infra branch merges last

### 3. Use feature flags instead of shared config changes

If two agents need to change the same config file, use a feature-flag pattern: each agent adds its own key under a namespaced section. They never edit the same line.

---

## Merge Order Strategies

### Strategy 1: Dependency graph (preferred)

Build a directed acyclic graph (DAG) of which branches depend on each other. Merge leaves first, roots last.

```text
feature/sprint-3-schema
    └──► feature/sprint-3-api
              └──► feature/sprint-3-ui
              └──► feature/sprint-3-tests
```

Merge order: `schema → api → ui → tests`

To detect dependencies programmatically:

1. For each branch, list changed files
2. Check if any other branch imports/requires those files
3. If branch B imports something introduced in branch A → A must merge before B

### Strategy 2: Conflict surface area (fallback)

When no explicit dependencies exist, merge in ascending order of conflict surface area:

1. Branches that touch zero shared files — merge first (clean, no risk)
2. Branches that touch low-conflict shared files (`.gitignore`, new docs) — merge second
3. Branches that touch high-conflict files (shared config, shared lib) — merge last with extra validation

### Strategy 3: Chronological (simplest, lowest safety)

Merge in the order branches were created (oldest first). This works when agents were given non-overlapping scopes, but it provides no protection against scope drift.

---

## When to Use merge-coordinator vs. Manual Merge

| Situation | Use |
|-----------|-----|
| ≥ 2 branches with no source code conflicts | `merge-coordinator` agent |
| Known dependency order, documentation/config conflicts only | `merge-coordinator` agent |
| Single branch, clean diff | Manual merge (`git merge --no-edit`) |
| Source code (`.ts`, `.cs`, `.py`) conflict in any branch | Manual merge — human required |
| Branches > 200 commits behind target | Manual merge — stale branch cleanup first |
| Merge of a breaking-change branch | Manual merge — review required before push |

---

## Safe Git Commands for Automated Agents

### ✅ Always use these

```bash
git merge origin/<branch> --no-commit --no-ff    # attempt merge, inspect first
git merge origin/<branch> --no-edit              # merge and auto-accept message
git commit --no-edit                             # commit with auto message
git commit -m "explicit message"                 # commit with explicit message
git cherry-pick <hash> --no-commit               # apply commit without committing
git merge origin/<branch> -X ours --no-edit      # take ours on conflict (docs only)
git merge origin/<branch> -X theirs --no-edit    # take theirs on conflict (docs only)
```

### ❌ Never use these in automated contexts

```bash
git rebase origin/main          # HANGS — opens editor on conflicts
git rebase --continue           # HANGS — opens editor for commit message
git commit                      # HANGS — opens editor for message
git merge --continue            # HANGS — opens editor for message
git rebase -i HEAD~N            # HANGS — interactive rebase, always requires editor
```

### Environment variables that prevent hangs

Set these at the start of any automated agent session:

```bash
export GIT_TERMINAL_PROMPT=0     # never prompt for credentials
export GIT_EDITOR=true           # no-op editor
export GIT_MERGE_AUTOEDIT=no     # suppress merge message editor
```

---

## Parallel Sprint Playbook (Step-by-Step)

### Before the sprint

1. Identify the sprint number and scope
2. Assign file ownership — document which agent owns which files
3. Create all branches from the same `main` commit (same base, minimal drift)
4. Share the branch list and dependency order with merge-coordinator

```bash
BASE=$(git rev-parse main)
for area in api ui data tests docs; do
  git checkout -b feature/sprint-3-$area $BASE
  git push origin feature/sprint-3-$area
done
```

### During the sprint

- Agents work in parallel on their branches
- Each agent runs in a fresh clone
- Agents do NOT merge or rebase against each other's branches mid-sprint
- If an agent discovers it needs something from another branch, it files an issue — it does not cherry-pick

### After the sprint (merge phase)

1. All agents push their final commits
2. Open PRs for all branches (target: `main`)
3. Run `merge-coordinator` agent with the branch list and dependency order
4. Review the merge report
5. Approve and merge PRs that were flagged clean or auto-resolved
6. Manually resolve any PRs flagged for human review

---

## Checklist: Is a Branch Ready to Merge?

- [ ] Branch is up to date with target (or merge-coordinator will handle it)
- [ ] All CI checks pass on the branch
- [ ] No secrets committed (gitleaks passes)
- [ ] PR description references the issue number (`Closes #NN`)
- [ ] Changed files are within the agent's assigned ownership scope
- [ ] No conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) left in files
- [ ] No debug files or local config files staged

---

## References

- `agents/basecoat-10-core-merge-coordinator.agent.md` — the automated merge agent
- `instructions/basecoat-20-lang-governance.instructions.md` — governance rules (priority:1)
- `docs/CONFIG_PATTERN.md` — local config pattern to avoid committing secrets
- Issue #51 — merge-coordinator origin story (parallel 5-agent sprint, rebase hang)

---

## Parallel Agent Execution

### When to Parallelize

- Independent research threads, such as exploring multiple modules simultaneously
- Non-overlapping file modifications across different services or components
- Multiple test suites or validation passes that can run independently
- Fan-out investigation before fan-in synthesis

### When NOT to Parallelize

- Tasks with data dependencies where the output of one step feeds another
- Overlapping file modifications where merge conflicts are guaranteed
- Sequential workflows such as build → test → deploy
- Tasks that require shared context accumulation in one place

### Canonical Sub-Agent Harness Contract

Use this contract as the single source of truth when dispatching and collecting
sub-agent work in multi-agent workflows.

#### Required task envelope (orchestrator → sub-agent)

| Field | Type | Required | Purpose |
|---|---|---|---|
| `task_id` | string | Yes | Stable identifier used for retries and traceability |
| `goal` | string | Yes | Outcome the sub-agent must achieve |
| `scope` | object | Yes | Bounded file paths and explicit out-of-scope constraints |
| `acceptance_criteria` | string[] | Yes | Testable checks used in Stage 1 spec compliance |
| `execution` | object | Yes | Allowed tools, skills, model, and operational limits |
| `output_contract` | object | Yes | Required response shape and evidence expectations |
| `inputs` | object | No | Optional context artifacts (issue links, prior findings, diffs) |
| `retry_context` | object | No | Prior failure reasons and focused re-dispatch guidance |

`execution` must include `allowed_files`, `allowed_tools`, `allowed_skills`, and
`model`.

When present, `retry_context` should include `attempt`, `failure_class`,
`last_feedback`, and `backoff_until` so redispatch behavior is deterministic.

#### Required response envelope (sub-agent → orchestrator)

| Field | Type | Required | Purpose |
|---|---|---|---|
| `task_id` | string | Yes | Correlates response to dispatched task |
| `status` | string | Yes | One of `completed`, `blocked`, `partial`, `failed` |
| `summary` | string | Yes | Brief outcome summary |
| `changed_files` | string[] | Yes | Files modified (empty array if none) |
| `acceptance_results` | object[] | Yes | Per-criterion pass/fail evidence |
| `evidence` | object | Yes | Commands, test outputs, and references supporting claims |
| `blockers` | string[] | Conditionally | Required when `status` is `blocked` or `failed` |
| `follow_ups` | string[] | No | Suggested next actions or tickets |

#### Concrete packet example

```json
{
  "task_envelope": {
    "task_id": "issue-1058-doc-contract",
    "goal": "Document canonical sub-agent harness contract in multi-agent workflows.",
    "scope": {
      "allowed_files": [
        "docs/agents/MULTI_AGENT_WORKFLOWS.md",
        "docs/agents/AGENT_RUNTIME_ENFORCEMENT.md",
        "docs/agents/agent-handoffs.md",
        "instructions/basecoat-10-core-subagent-review.instructions.md"
      ],
      "out_of_scope": [
        "agent behavior changes",
        "workflow automation changes"
      ]
    },
    "acceptance_criteria": [
      "Canonical contract section added with task and response envelopes.",
      "AGENT_RUNTIME_ENFORCEMENT.md links to canonical contract.",
      "agent-handoffs.md links to canonical contract and clarifies handoff vs contract.",
      "subagent-review.instructions.md references canonical contract."
    ],
    "execution": {
      "allowed_files": [
        "docs/agents/**",
        "instructions/basecoat-10-core-subagent-review.instructions.md"
      ],
      "allowed_tools": ["view", "rg", "apply_patch"],
      "allowed_skills": [],
      "model": "claude-sonnet-4.6"
    },
    "output_contract": {
      "format": "response_envelope_v1",
      "include_evidence": true
    }
  },
  "response_envelope": {
    "task_id": "issue-1058-doc-contract",
    "status": "completed",
    "summary": "Canonical contract documented and linked from required docs.",
    "changed_files": [
      "docs/agents/MULTI_AGENT_WORKFLOWS.md",
      "docs/agents/AGENT_RUNTIME_ENFORCEMENT.md",
      "docs/agents/agent-handoffs.md",
      "instructions/basecoat-10-core-subagent-review.instructions.md"
    ],
    "acceptance_results": [
      {
        "criterion": "Canonical contract section added with task and response envelopes.",
        "result": "pass",
        "evidence": "See section: Canonical Sub-Agent Harness Contract"
      }
    ],
    "evidence": {
      "commands": ["pwsh scripts/validate-basecoat.ps1"],
      "artifacts": []
    },
    "blockers": [],
    "follow_ups": []
  }
}
```

#### Handoff UI vs. harness contract

- **Handoff UI (`handoffs`)** defines user-facing transitions between agents.
- **Harness contract** defines machine-readable dispatch/response packets used by
  orchestrators and review gates.
- A handoff can launch a sub-agent task, but it does not replace the required task
  and response envelopes above.

### Sub-Agent Redispatch, Retry, and Escalation Policy

Use this table as the canonical orchestration policy for sub-agent runs.

| Condition | Re-dispatch action | Retry/backoff | Escalation threshold | Terminal state |
|---|---|---|---|---|
| Stage 1 spec-compliance failure | Re-dispatch with unmet criteria and explicit expected deltas | Immediate retry on first miss; second miss requires at least 5-minute cool-down and tightened scope | 2 Stage 1 misses for same `task_id` | `escalated` (human review or task re-plan) |
| Stage 2 quality failure after Stage 1 pass | Re-dispatch with line-level quality fixes only | One retry only; no additional retries beyond second quality review | 1 Stage 2 retry consumed with unresolved quality gaps | `accepted_with_followup` (merge best version + file follow-up issue) |
| Transient tool/runtime failure (timeouts, rate limits, ephemeral network faults) | Re-dispatch unchanged goal with infra diagnostics attached | Exponential backoff: 2m, 5m, 15m (max 3 retries) | 3 transient retries exhausted | `escalated` (operator intervention required) |
| No-progress rerun (>= 80% identical output or repeated unmet criteria) | Re-dispatch only if feedback packet materially changes constraints | Minimum 10-minute backoff; require updated acceptance criteria or narrowed scope | 2 no-progress reruns | `escalated` (plan defect or wrong agent routing) |
| Budget/context exhaustion (token, tool, or turn budget reached) | Re-dispatch with reduced scope and explicit budget limits | One retry after decomposition; split task before retrying | Retry still exceeds budget | `replanned` (decompose into smaller tasks) |
| Hard blocker (missing dependency, required secret, policy restriction) | Do not re-dispatch blindly; return blocker with owner/action needed | No automatic retry | Immediate | `blocked` |

Policy notes:

- Re-dispatch feedback must never be "try again". It must include failed criteria,
  expected artifact/file deltas, and any new constraints.
- Every re-dispatch must increment `retry_context.attempt` and preserve failure
  history for auditability.
- If escalation triggers, halt auto-redispatch loops for the `task_id`.

### Orchestrator Lifecycle: Dispatch, Fan-In, and Conflict Resolution

Use this lifecycle when an orchestrator runs fan-out work and must converge to one
final answer.

Visual diagram set:
[orchestrator-dispatch-fan-in-conflict-resolution.md](../diagrams/orchestrator-dispatch-fan-in-conflict-resolution.md)

#### Sequence

1. **Plan and scope** — decompose request, define task envelopes, and set budgets.
2. **Dispatch (fan-out)** — start all independent subtasks in parallel.
3. **Collect branch results** — normalize each response envelope and validate
   required fields.
4. **Fan-in synthesis** — merge non-conflicting branches into one draft result.
5. **Conflict resolution pass** — apply decision points below for contradictory
   claims, file edits, or policy outcomes.
6. **Finalize and report** — publish one coherent response with explicit branch
   statuses and unresolved risks.

#### Lifecycle states

| State | Entry condition | Exit condition |
|---|---|---|
| `planned` | Task decomposition and envelopes are complete | At least one subtask dispatched |
| `dispatching` | Dispatch loop is active | All runnable branches dispatched or marked blocked |
| `running` | One or more branches are executing | All branches return terminal status |
| `fan_in_ready` | All terminal branch results collected | Aggregation begins |
| `aggregating` | Result merge and dedupe in progress | No conflicts remain, or conflicts identified |
| `conflict_review` | Contradictions detected during aggregation | Tie-break decision applied or unresolved risk recorded |
| `finalized` | Output assembled with evidence and status table | Response delivered |

#### Conflict-resolution decision points

| Decision point | Check | Action |
|---|---|---|
| `CR-1` contract validity | Missing required fields or acceptance evidence in a branch result | Mark branch `partial` or `blocked`, request targeted retry with `retry_context` |
| `CR-2` evidence strength | Contradictory conclusions with different evidence quality | Prefer reproducible test/log/repo evidence over unsupported narrative claims |
| `CR-3` policy gate | Any side-effecting recommendation conflicts with policy | Apply [VS Code Agent Mode Tool Confirmation Policy](../reference/guardrails/tool-confirmation-policy.md) and require confirmation path |
| `CR-4` unresolved tie | Evidence remains mixed after one tie-break pass | Surface both interpretations, mark residual risk, and recommend next verification step |

#### Related harness and policy docs

- [Orchestrator Dispatch, Fan-In, and Conflict Resolution Flow](../diagrams/orchestrator-dispatch-fan-in-conflict-resolution.md)
  — sequence, status lifecycle, and tie-break decision visuals.
- [Agent Testing Harness](./agent-testing-harness.md) — run/turn/round semantics,
  stop conditions, and cancellation behavior for dispatch loops.
- [VS Code Agent Mode Tool Confirmation Policy](../reference/guardrails/tool-confirmation-policy.md)
  — confirmation requirements for side-effecting operations.
- [Agent Runtime Enforcement](./agent-runtime-enforcement.md) — enforcement
  expectations that constrain orchestrator and sub-agent execution.

### Patterns

#### Fan-Out / Fan-In

- Decompose a task into `N` independent subtasks
- Dispatch `N` agents simultaneously
- Collect results, resolve conflicts, and synthesize the final output
- Use for: code exploration, multi-file implementation, parallel testing

#### Subagent Isolation

- Launch subagents for research or investigation
- Keep the main context clean by summarizing subagent findings back into the parent workflow
- Use for: understanding unfamiliar code, exploring alternatives, impact analysis

#### Parallel Implementation with Conflict Detection

- Assign non-overlapping file sets to each agent
- Use separate git branches, one per agent
- Merge sequentially with conflict detection between each merge
- If conflicts appear, resolve them manually or assign them to a merge-coordinator agent

#### Result Aggregation

- Define the expected output format before dispatching agents
- Collect all results into a single synthesis
- Handle partial failures: if 1 of `N` agents fails, continue with the remaining `N-1` results where possible
- Report which agents succeeded, which failed, and why

### Anti-Patterns

- Do not parallelize and then duplicate work by re-investigating what subagents already found
- Do not launch speculative agents "just in case" — they waste resources
- Do not fan out without a clear fan-in strategy
- Do not parallelize tasks that share mutable state
