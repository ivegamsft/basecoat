---
description: "CRITICAL — Read this first. Governance rules for all AI agents working in this repository. Covers issue-first mandate, secret policy, PR-only workflow, branch naming, when to stop vs proceed, and token/model awareness stub."
applyTo: "**/*"
priority: 1
distribute: false
---

# Governance Instructions for AI Agents

**This file is authoritative. Read it before doing anything else in this repository.**

These are not suggestions. Every AI agent operating in `ivegamsft/basecoat` must follow these rules without exception.

## LOG-FIRST Gate

Before writing any code, modifying any file, or executing any side-effecting tool
call, the agent **must** confirm that a tracking issue exists. This is a hard block —
do not skip it.

**Gate sequence:**

1. **Identify** the issue number from the current task context, user message, or
   session state.
2. **Verify** the issue exists: run `gh issue view <number>` and confirm it is open
   and describes the work being started.
3. **Pause** — do not begin implementation in the same turn as issue creation.
4. **Only then proceed** with implementation, referencing the issue number in every
   commit message.

If no issue number is present:

- Do NOT start implementation.
- Create a tracking issue first: `gh issue create --title "<description>" --body "<context>"`.
- Confirm the issue was created and note its number.
- Return to the user or session with the issue link before proceeding to any code changes.

This gate applies to every implementation intent: `bug:`, `feature:`, `chore:`,
`refactor:`, `test:`, `deploy:`, and `fix`.

**The most common failure mode:** creating the tracking issue and immediately
continuing to implement in the same step without pausing to confirm the issue is
the authoritative work record. Logging and implementing must be separate steps.

---

## Hard Rules

- **Issue-first:** No implementation without an issue number. No issue = hard stop.
  Satisfy the LOG-FIRST gate above before any code change.
- **No secrets:** Never write API keys, tokens, passwords, PII, or connection strings to any file, commit, or comment. If a task requires a secret, stop and ask the operator.
- **Internal-only GitHub writes:** Never create/update issues, PRs, or comments in non-allowlisted repositories. Use deny-by-default with an explicit internal allowlist.
- **Workflow secrets:** GitHub Actions must use `${{ secrets.SECRET_NAME }}` — no literals. See [`docs/guardrails/secrets-in-workflows.md`](/docs/guardrails/secrets-in-workflows.md).
- **PR-only:** Never push directly to `main`. Always open a PR and wait for CI to pass.
- **OIDC for Azure:** Use `azure/login@v2` with federated credentials. No stored client secrets in GitHub Secrets. See [`docs/guardrails/oidc-federation.md`](docs/guardrails/oidc-federation.md).
- **Container tags:** Always tag images with the full git commit SHA. `:latest`-only is a policy violation. See [`docs/guardrails/container-image-tags.md`](docs/guardrails/container-image-tags.md).
- **CAF naming:** All Azure resources must follow CAF conventions. See [`docs/guardrails/caf-naming.md`](docs/guardrails/caf-naming.md).
- **Env vars:** Every repo requiring env vars must have `.env.example` at root. Real values are gitignored. See [`docs/guardrails/env-example.md`](docs/guardrails/env-example.md).
- **DB migrations:** Workflows running DB migrations must set `cancel-in-progress: false`. See [`docs/guardrails/db-deployment-concurrency.md`](docs/guardrails/db-deployment-concurrency.md).
- **Deployment cancellation:** Run a pre-flight check before stopping any in-progress infrastructure deployment. See [`docs/guardrails/deployment-cancellation.md`](docs/guardrails/deployment-cancellation.md).
- **Tool confirmation:** In VS Code agent mode, side-effecting tool calls require explicit user confirmation before execution. See [`docs/reference/guardrails/tool-confirmation-policy.md`](../docs/reference/guardrails/tool-confirmation-policy.md).
- **Sub-agent redispatch policy:** Orchestrators must follow the canonical redispatch/retry/escalation policy and stop auto-loops at escalation threshold. See [`docs/agents/MULTI_AGENT_WORKFLOWS.md#sub-agent-redispatch-retry-and-escalation-policy`](../docs/agents/MULTI_AGENT_WORKFLOWS.md#sub-agent-redispatch-retry-and-escalation-policy).

## Batch PR Size Guideline

- Prefer one issue per PR.
- Batch only tightly related changes that are reviewable in one pass.
- Keep batch PRs to **15 files or fewer** and **300 changed lines or fewer** (additions + deletions).
- If a batch must exceed either limit, split it or document the mechanical reason in the PR description.
- Large mechanical batches should include validation evidence, a rollback note, and PRD/spec links when the change is high-risk or high-change.

## Branch Naming

```text
<type>/<issue-number>-<short-description>
```

Types: `feat` | `fix` | `docs` | `chore` | `security`

## Commit Format

```text
<type>(<scope>): <short summary> (#<issue-number>)
```

First line ≤ 72 characters. Never include secrets or PII.

## Model and Token Guidance

- **Premium** (`claude-opus-4.7`, `claude-opus-4.6`) — architecture, security, compliance
- **Reasoning/Standard** (`claude-sonnet-4.6`, `gpt-5.4`) — code review, planning, research
- **Code** (`gpt-5.3-codex`, `gpt-5.2-codex`) — implementation, refactoring, generation
- **Fast** (`claude-haiku-4.5`, `gpt-5.4-mini`) — scanning, formatting, simple automation

See `docs/MODEL_OPTIMIZATION.md` for the full tier matrix. See `docs/token-optimization.md` for context loading strategies.

## Quick Reference Card

| Rule | Action |
|---|---|
| No issue | Stop — satisfy LOG-FIRST gate; create issue, pause, then proceed |
| LOG-FIRST gate not satisfied | Hard block — do not start implementation |
| Secret needed | Stop, ask operator |
| GitHub write target | Validate `owner/repo` against internal allowlist before write |
| Direct main push | Never — use PR |
| Scope expanded | Stop, ask if new issue needed |
| CI failing | Fix before merge |
| Sprint closeout | Run verify → merge → prune → close/report |
| Azure auth in Actions | OIDC only — no client secrets |
| Container image tag | Must include full git SHA |
| Azure resource naming | CAF conventions |
| Env vars undocumented | Add to `.env.example` |
| DB migration workflow | `cancel-in-progress: false` |
| Stop deployment mid-flight | Pre-flight check required |
| VS Code side-effecting tool call | Require explicit confirmation before execution |
| Sub-agent run fails repeatedly | Follow canonical redispatch policy; escalate at threshold |
| Message has `bug:` / `feature:` prefix | See intent-routing instructions |
| Bulleted `- feature:` item | Log to backlog; do not implement |

## References

| Topic | File |
|---|---|
| PR workflow, branch naming, commit format, file placement, PR template | [`references/governance/workflow-rules.md`](references/governance/workflow-rules.md) |
| Sprint close sequence and command checklist | [`references/governance/workflow-rules.md#sprint-close-workflow-verify--merge--prune--closereport`](references/governance/workflow-rules.md#sprint-close-workflow-verify--merge--prune--closereport) |
| When to stop vs proceed, agent accountability rules | [`references/governance/agent-self-governance.md`](references/governance/agent-self-governance.md) |
| OIDC, CAF naming, container tags, env-example, DB concurrency, deployment cancellation | [`references/governance/guardrails-reference.md`](references/governance/guardrails-reference.md) |
| VS Code tool confirmation tiers and enforcement | [`docs/reference/guardrails/tool-confirmation-policy.md`](../docs/reference/guardrails/tool-confirmation-policy.md) |
| Sub-agent redispatch/retry/escalation policy | [`docs/agents/MULTI_AGENT_WORKFLOWS.md#sub-agent-redispatch-retry-and-escalation-policy`](../docs/agents/MULTI_AGENT_WORKFLOWS.md#sub-agent-redispatch-retry-and-escalation-policy) |
| Intent prefix routing, timing semantics, prefix-to-agent map | [`instructions/basecoat-10-core-intent-routing.instructions.md`](../instructions/basecoat-10-core-intent-routing.instructions.md) |
