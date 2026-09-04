# Agent Examples

Practical examples for the most common jobs you'll use BaseCoat agents for.
Each example shows what to say, what comes back, and how to chain agents when one
job naturally leads into the next.

Jump to: [Audit](#audit) · [Build & Integrate](#build--integrate) ·
[Plan a Sprint](#plan-a-sprint) · [Review & Harden](#review--harden) ·
[Update & Upgrade](#update--upgrade) · [Publish Learnings](#publish-learnings) ·
[Monitor & Respond](#monitor--respond)

---

## Audit

### Scan a repo for exposed secrets and config gaps

**Agent:** `@config-auditor`

```text
@config-auditor Scan this repository for committed credentials, exposed API keys,
and missing .gitignore coverage. Report findings by severity with remediation steps.
```

**What comes back:**

- A findings report grouped by severity (Critical / High / Medium / Low)
- Each finding includes the file, line, and a specific remediation step
- A `.gitignore` coverage gap list if required entries are missing
- A summary count: `3 Critical, 7 High, 2 Medium`

**Typical follow-up:** The agent flags a hardcoded connection string. You ask:

```text
@config-auditor The postgres connection string in src/config/db.ts is flagged.
Generate a remediation PR description and the corrected code using an environment variable.
```

---

### Audit your GitHub security posture

**Agent:** `@github-security-posture`

```text
@github-security-posture Audit this repository's GitHub security settings.
Check branch protection, secret scanning, Dependabot, CODEOWNERS, and workflow permissions.
```

**What comes back:**

- Per-setting pass/fail with the current state and the recommended state
- Prioritized fix list ordered by risk
- Ready-to-run `gh` CLI commands to apply each fix

---

### Code quality audit before a release

**Agent:** `@code-review`

```text
@code-review Review the diff between main and release/v2.1 for correctness,
regression risk, and missing test coverage. Focus on the auth and payment modules.
```

**What comes back:**

- Findings by severity (Critical / High / Medium / Low / Info)
- Each finding: file reference, description, suggested fix
- Test coverage gaps: which changed paths have no associated test changes
- A handoff option: **Run Security Review** → routes the critical findings
  directly to `@security-analyst`

---

### Audit BaseCoat assets for quality

**Agent:** Run the built-in quality gate directly (no agent needed):

```powershell
pwsh scripts/audit-assets.ps1 -Report
```

Or from CI:

```powershell
pwsh tests/quality-gate-tests.ps1
```

**What comes back:**

- Per-asset scores (0–10) across five dimensions: description quality,
  workflow completeness, input/output clarity, compatibility, governance
- Aggregate score with pass/fail against the 5.0/10 threshold
- Red assets (score ≤ 0.5) listed explicitly — these block CI

---

## Build & Integrate

### Design a new feature end-to-end

**Chain:** `@solution-architect` → `@backend-dev` → `@code-review`

**Step 1 — Architecture:**

```text
@solution-architect Design the data model, API contracts, and component boundaries
for a multi-tenant audit log feature. We store events in Postgres, expose them via
REST, and need 90-day retention with GDPR deletion support.
```

**What comes back:** C4 component diagram (Mermaid), ADR for storage choice,
API contract (OpenAPI snippet), risk table. Includes a **Start Backend Implementation**
handoff button.

**Step 2 — Implementation (via handoff or directly):**

```text
@backend-dev Implement the audit log API from the architecture above.
Create the Postgres migration, the repository layer, the service, and the REST routes.
```

**What comes back:** Migration file, TypeORM entity, service, controller, route
registration, and unit test scaffolding.

**Step 3 — Review:**

```text
@code-review Review the audit log implementation above. Focus on the delete path
for GDPR compliance and the Postgres index strategy for the tenant_id + created_at query.
```

---

### Add a new agent to BaseCoat

**Agent:** `@agent-designer`

```text
@agent-designer Create a new agent for dependency lifecycle management.
It should scan package.json and requirements.txt files, identify outdated dependencies,
assess breaking change risk, and produce an upgrade plan.
```

**What comes back:**

- A complete `.agent.md` file with correct frontmatter (name, description,
  compatibility, model, allowed_skills)
- Inputs, Workflow, and Expected Output sections filled in
- Suggested handoffs to `@code-review` and `@release-manager`

Then validate it:

```powershell
pwsh scripts/validate-basecoat.ps1
```

---

### Integrate a new service into an existing system

**Agent:** `@api-designer` then `@backend-dev`

```text
@api-designer Design the integration contract between our order service and
the new fulfillment API. We need: webhook registration, retry with exponential
backoff, idempotency keys, and a dead-letter queue for failed events.
```

**What comes back:** OpenAPI spec for the integration surface, idempotency
key strategy, retry configuration table, and DLQ design. Use the result as
context for `@backend-dev` to implement.

---

## Plan a Sprint

### Decompose a sprint goal into issues

**Agent:** `@sprint-planner`

```text
@sprint-planner Sprint goal: Ship the memory triage feature — consumers can
self-screen learnings before submitting, and the steward team has a structured
review checklist. Sprint 25, repository: ivegamsft/basecoat, team size: 3.
```

**What comes back:**

- GitHub issues with labels, acceptance criteria, and story points
- A wave dependency map (what can run in parallel, what must sequence)
- Agent assignments per issue (e.g., `@tech-writer` for docs, `@backend-dev` for scripts)
- A **Begin Backend Sprint Work** handoff to `@backend-dev`
- A **Begin Frontend Sprint Work** handoff to `@frontend-dev`

**After planning:**

```powershell
# Open all issues from the sprint plan at once
gh issue list --label sprint-25 --json number,title | ConvertFrom-Json |
  ForEach-Object { gh issue view $_.number --web }
```

---

### Run a retrospective

**Agent:** `@sprint-retrospective`

```text
@sprint-retrospective Sprint 24 retrospective. Velocity: 31/34 points.
Three items carried over: consumer-sync.md doc fix, generate-registry CI wiring,
performance-baseline-pr-check.yml cleanup. Main blocker: rate limit hits when
dispatching 5 concurrent agents. Team size: 2. Duration: 2 weeks.
```

**What comes back:**

- What went well / what didn't / what to try next
- Action items with owners and priority
- Patterns to consider submitting to memory (e.g., the rate limit discovery)
- Carry-over analysis: why items slipped and whether the root cause is addressed

---

## Review & Harden

### Security review of a new feature

**Agent:** `@security-analyst`

```text
@security-analyst Perform a security review of the new audit log feature.
Focus on: tenant isolation (can user A query user B's logs?), SQL injection risk
in the filter parameters, GDPR deletion completeness, and the webhook endpoint
authentication.
```

**What comes back:**

- Threat model (what an attacker could do, likelihood, impact)
- OWASP Top 10 mapping for each finding
- Specific code references with remediation steps
- Test cases to validate each remediation

---

### Check CI and governance alignment

**Agent:** `@guidance-reviewer`

```text
@guidance-reviewer Review the governance.instructions.md file for internal
consistency and alignment with what CI actually enforces. Flag any rules that
are stated as hard requirements but have no enforcement mechanism.
```

**What comes back:**

- Rule-by-rule table: stated requirement vs. enforcement state (Enforced / Warn-only / None)
- Recommendations: which gaps to close in CI vs. which to downgrade to advisory
- Ready-to-commit instruction file edits where wording overstates enforcement

---

### Production readiness check before launch

**Agent:** `@production-readiness`

```text
@production-readiness Run a production readiness review for the audit log feature.
Check: error handling coverage, observability (structured logs, metrics, traces),
graceful degradation, health endpoint, runbook exists, rollback plan documented.
```

**What comes back:**

- Checklist with pass/fail per criterion
- Gaps with severity and suggested remediation
- A readiness score (e.g., 8/11 criteria met — not ready)

---

## Update & Upgrade

### Roll BaseCoat out to a new repo

**Agent:** `@rollout-basecoat`

```text
@rollout-basecoat Onboard the repo myorg/payments-service to BaseCoat v4.2.1.
Enterprise constraints: no direct internet access — must pull from our internal
mirror at artifacts.myorg.internal/basecoat.
```

**What comes back:**

- Step-by-step rollout plan with the correct internal mirror configuration
- Validation checklist: which files should exist after sync
- Version pinning instructions
- Upgrade path for future releases

Or run the bootstrap script directly:

```powershell
pwsh scripts/bootstrap-basecoat.ps1 `
  -BasecoatRepo https://artifacts.myorg.internal/basecoat.git `
  -Ref v4.2.1
```

---

### Update outdated dependencies

**Agent:** `@dependency-update-advisor`

```text
@dependency-update-advisor Scan package.json and requirements.txt for dependencies
that are more than one major version behind. Assess breaking change risk for each,
and produce an upgrade sequence that minimizes CI failures.
```

**What comes back:**

- Per-dependency table: current version, latest, breaking change risk (High/Med/Low)
- Recommended upgrade sequence (safest first)
- Changelog highlights for High-risk upgrades
- Test strategy: which test suites to run after each upgrade batch

---

### Coordinate a release

**Agent:** `@release-manager`

```text
@release-manager Prepare the v4.2.1 release. Changes since v4.2.0:
post-release stabilization, workflow approval fixes, token-budget reductions,
and documentation corrections.
Validate tests pass, bump version.json,
draft the CHANGELOG entry, and generate the release notes.
```

**What comes back:**

- CHANGELOG entry in the correct format
- `version.json` update
- GitHub release draft with structured notes (New, Fixed, Internal)
- Tag command ready to copy-paste

---

## Publish Learnings

### Surface memory candidates from a completed sprint

**Agent:** `@memory-promoter`

```text
@memory-promoter Analyze the Sprint 24 session history for recurring fix patterns
and non-obvious discoveries. Session state folder: ~/.copilot/session-state/.
Minimum frequency: 2 occurrences. Filter out anything repo-specific.
```

**What comes back:**

- Ranked list of memory candidates with frequency, impact score, and suggested fact text
- Each candidate includes: subject, fact (≤200 chars), citations, reason for storing
- Candidates are ready to pipe into `submit-learning.ps1`

**Submit the top candidates:**

```powershell
# Submit a single learning
pwsh scripts/submit-learning.ps1 `
  -Subject "ci:check-coherence-default-exit" `
  -Fact "check-coherence.ps1 exits 0 unless -Strict is passed. CI is non-blocking without it." `
  -Evidence "https://github.com/ivegamsft/basecoat/issues/709" `
  -Domain "ci" `
  -Source "ivegamsft/basecoat" `
  -OpenPR
```

---

### Collect and act on feedback about agent quality

**Agent:** `@feedback-loop`

```text
@feedback-loop Analyze the last 30 days of session data for the code-review agent.
Identify patterns where users immediately re-asked after the first response,
edited the agent output heavily, or flagged the finding as wrong. Suggest
instruction refinements.
```

**What comes back:**

- Failure pattern summary (what categories of output were reworked most)
- Specific instruction changes with before/after diffs
- A/B test design if the change is high-risk (two variants, sample size, measurement criteria)

---

## Monitor & Respond

### Set up observability for a service

**Agent:** `@observability-engineer`

```text
@observability-engineer Add structured logging, metrics, and traces to the
audit log service. Stack: Node.js + Express + Postgres. Target: Azure Monitor
with Application Insights. We need request tracing across the webhook and
REST API paths.
```

**What comes back:**

- Middleware additions for structured logging (JSON, with request-id propagation)
- Metrics: which counters, histograms, and gauges to add and where
- Trace instrumentation with span boundaries
- Azure Monitor workspace config and dashboard template

---

### Respond to a production incident

**Agent:** `@incident-responder`

```text
@incident-responder P1 incident: audit log writes are failing in the EU region.
Symptoms: 503s from POST /audit/events since 14:32 UTC. DB connection pool
exhausted. US region healthy. On-call: @alice. Incident channel: #inc-2024-0521.
```

**What comes back:**

- Immediate mitigation steps (ordered, copy-paste ready)
- Root cause hypotheses ranked by likelihood
- Data to collect (specific log queries, metrics to pull)
- Stakeholder communication draft
- Post-incident review checklist

---

## Chaining Agents: Common Pipelines

### Full feature pipeline

```text
sprint-planner     → decomposes goal into issues
  └─ solution-architect  → designs the system
       └─ backend-dev    → implements it
            └─ code-review       → reviews the implementation
                 └─ security-analyst    → security pass
                      └─ production-readiness  → launch gate
```

### Sprint close pipeline

```text
sprint-retrospective    → what happened, what to carry
  └─ memory-promoter    → surface candidates from session history
       └─ submit-learning.ps1   → publish approved candidates
            └─ release-manager  → tag and publish the release
```

### Security hardening pipeline

```text
config-auditor          → finds exposed secrets / config gaps
github-security-posture → GitHub settings audit
  └─ security-analyst   → threat model + remediation
       └─ hardening-advisor     → infrastructure hardening
            └─ production-readiness    → readiness gate
```

---

## Tips

**Call agents directly by name.** Use `@agent-name` for any task you already
know — no router needed. The [routing decision tree](../../.github/instructions/routing-decision-tree.md)
maps 40+ intents to direct agent or skill calls:

```text
@issue-triage Triage all open bugs in the backlog
@sprint-planner Plan sprint 34 from open GitHub issues
@code-review Review PR #142, focus on auth middleware
```

For initial exploration, invoke the `basecoat` discovery skill in Copilot Chat
to browse the full agent catalog by category.

**Delegate, don't just ask.** Agents work best when given a concrete deliverable:

```text
# Too vague:
@code-review Look at the PR

# Concrete:
@code-review Review PR #142. Focus on the auth middleware refactor and
whether the JWT expiry check is preserved across all code paths.
```

**Use handoffs for natural transitions.** When an agent finishes and shows a
handoff button (e.g., **Run Security Review**), clicking it pre-loads the
context from the current session — you don't have to re-explain.

**Check the `## Model` section** of each agent file if cost matters. Fast-tier
agents (Haiku) handle scanning and automation. Reasoning-tier (Sonnet) handles
analysis. Premium (Opus) handles architecture and security reviews.
