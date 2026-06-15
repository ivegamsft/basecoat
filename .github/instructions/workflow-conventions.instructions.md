---
description: "Git workflow, branch naming, commit conventions, and Copilot agent triggers"
applyTo: ".github/**/*,*.md"
---

# Workflow Conventions

## Branch and Commit Conventions

- Branches: `<type>/<issue-number>-<short-description>` (e.g., `feat/1334-split-instructions`)
- Commits: `<type>(<scope>): <summary>` (conventional commits)
- Always include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` trailer

Example:

```bash
git checkout -b feat/1334-split-instructions
git add . && git commit -m "feat(instructions): split monolithic copilot-instructions.md into 7 targeted files

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## PR Workflow

Standard pattern for all changes:

```bash
git checkout -b <type>/<issue>-<desc>
git add . && git commit -m "<type>(<scope>): <summary>"
gh auth switch --user ibuyspy
git push origin <branch>
gh pr create --title "<title>" --body "<body>"
gh pr merge --squash --admin
```

Use `--admin` to bypass CI wait when change is pre-validated locally.

## CLI session transition policy

For long runs, enforce context transitions explicitly:

1. **Triage -> implementation**: run `/compact`.
2. **Implementation -> merge waiting**: run `/compact`.
3. **Domain pivot** (for example sprint planning -> release triage): run `/new`.
   Reload only the required references.

Message hygiene:

- Do not paste large instruction blocks into chat; reference files by path.
- Normalize rich-file inputs (PPTX, PDF, DOCX, XLSX) into one markdown summary artifact before passing context between turns or agents.
- Batch related operations in one turn.
- Keep the main thread focused on decisions and outcomes; use delegation for broad scan/research work.
- Prefer Ask mode for small, direct queries and edits; switch to Agent mode for multi-file execution, long-running workflows, or broad investigations.
- For full token-optimization defaults and MCP overhead checks, follow `.github/instructions/cost-optimization.instructions.md` and `docs/reference/scoped-instructions.md`.

## Fleet Merge Pacing

During fleet or burndown sessions, enforce serialized merge pacing:

1. Queue work in parallel if needed, but merge one PR at a time.
2. Before each merge, confirm required checks are green and mergeability is clean.
3. Wait for merge completion before starting the next merge.
4. After each merge, clean up local and remote branch state before continuing.

## PR Flow Hygiene Guardrails

Use the `pr-flow-hygiene.yml` workflow as the fixed-cadence PR backlog guardrail:

1. Run weekly on Monday and publish a visible PR flow report issue.
2. Track and enforce these thresholds:
   - Ready-for-review WIP limit (default: 20)
   - Draft drift age threshold (default: 14 days)
   - Ready-for-review inactivity threshold (default: 7 days)
3. Upsert triage nudges on flagged PRs (owner/reviewer/drift gaps) instead of silent reporting only.
4. Use manual dispatch inputs only for temporary threshold tuning during incident/backlog recovery windows.

## Token-Efficient Operating Defaults

Use these defaults unless task complexity requires escalation:

1. Keep responses concise by default and expand only when risk, ambiguity, or investigation depth requires it.
2. Start in Auto/default model routing for routine work; upshift only for ambiguous cross-system root-cause work, security-sensitive review, large behavior-preserving refactors, or architectural tradeoff decisions.
3. Compact or otherwise reduce context before blaming model choice; context reduction is the primary cost lever.
4. Audit each tool call for overhead: prefer direct file tools for local repo work and reserve remote/MCP calls for data not available in-repo.

## Triggering the Copilot Coding Agent

Post `/approve` as an issue comment to trigger the Copilot coding agent workflow
(`issue-approve.yml`). This adds `approved` + `copilot-agent` labels and assigns
the issue to Copilot. The `@copilot` mention does **not** trigger the agent.

## Keep/Fix/Throttle Operating Model

BaseCoat uses a Keep/Fix/Throttle governance framework to balance agent autonomy with safety:

| Tier | Pattern | Approval | Timeout | Rollback |
|------|---------|----------|---------|----------|
| **Keep** | Standardized, proven patterns | None | Ongoing | N/A |
| **Fix** | Recurring failures as product work | None | 1–2 week cycle | Tracked in failure archive |
| **Tier 1** | Read-only feedback | None | N/A | N/A |
| **Tier 2** | Staging deployments, feature merges | PR review | 2h | Auto (health check) |
| **Tier 3** | Production merge, quota changes | SLA + explicit approval | 4h | Manual |
| **Tier 4** | Emergency, account-level changes | Admin + on-call | Real-time | Manual + incident runbook |

**How to apply**:

1. Classify workflow or operation by risk tier (see `docs/reference/risk-tier-policy.md`).
2. Add tier label to workflow: `env.RISK_TIER: "1"` (or 2, 3, 4).
3. Enforce tier governance in CI via status checks (approval, timeout, validation).
4. Document runbook for each tier workflow (see `docs/operations/operational-runbook.md` template).

**Reference**: `docs/operations/keep-fix-throttle-model.md` (full framework and measurable criteria).

## Worktrees

When creating worktrees, use naming pattern: `../<repo>-wt-<issue-or-pr>` (e.g., `../basecoat-wt-1334`).

Worktree cleanup safety playbook:

1. Verify branch-to-path mapping with `git worktree list` before removal.
2. Never delete worktrees by assumed paths.
3. Use `git worktree prune` only after mapping is confirmed and stale entries are identified.
