# Downstream Prompt Catalog

This guide is the downstream-user entry point for BaseCoat agents, skills, and
intent prefixes. It explains what to ask for, how a request flows through the
framework, and what shape of result to expect.

The generated [prompt library](../reference/prompt-library.md) contains the
complete asset-derived catalog: 33 intents, 133 skills, and 130 agents. This
guide adds the usage contract and representative prompts without duplicating
every asset definition.

## Quick start

Use one recognized intent prefix when the work has a clear SDLC shape:

```text
audit: review the GitHub Actions workflows for secret exposure; read-only
```

Use the unprefixed router when you know the outcome but not the specialist:

```text
Find the right BaseCoat agent for reviewing an API contract.
```

Use an explicit asset when the workflow is already known:

```text
@sprint-planner prepare a dependency-ordered wave from the oldest actionable issues
```

For a multi-step request, use `optimize:` first so the execution packet makes
scope, stop conditions, validation, and routing explicit:

```text
optimize: plan, implement, test, and release audit logging for the orders API
```

## Integrate, onboard, inventory, and audit

Use this single prompt when a downstream repository needs to adopt BaseCoat and
apply this guidance. It combines discovery, inventory, audit, and an approval
boundary before any change:

```text
optimize: integrate this repository with BaseCoat using the downstream prompt catalog.

First run a read-only inventory and audit:
- detect whether BaseCoat is already installed
- identify repository-owned versus BaseCoat-managed files
- inspect version, drift, compatibility, and policy configuration
- map applicable agents, skills, intents, instructions, and documentation
- identify missing, conflicting, stale, or ambiguous guidance

Then prepare an onboarding and integration plan using this catalog and the
generated prompt library.

Do not modify files, create issues, open pull requests, or delete anything
during discovery.

Return: status, scope, evidence, current inventory, audit findings, proposed
changes, validation plan, handoffs, and stop reason.

After presenting the plan, wait for approval before applying changes.
```

## Product definition and design debate

Use `design:` when onboarding a downstream repository's product and design
context. The repository's `PRODUCT.md` is the product-truth input; it is not
safe to infer or replace from BaseCoat defaults.

```text
design: debate: onboard this repository using PRODUCT.md and the design-debate format at `.github/base-coat/docs/reference/design-debate-format.md` (or custom overlay location).

First run a read-only inventory:
- locate PRODUCT.md and identify its product, users, purpose, boundaries, and
  design principles
- inspect existing UI, UX, information architecture, accessibility, and design
  system guidance
- identify conflicts, missing sections, stale terminology, and assumptions

Debate the smallest viable options for resolving each gap. Follow
`.github/base-coat/docs/reference/design-debate-format.md` (or custom overlay location). For every option,
include evidence, user impact, implementation scope, accessibility impact,
risks, and a recommendation. Do not edit PRODUCT.md, design files, issues, or
pull requests during discovery.

Return: product-definition status, evidence, design debate, decision points,
proposed changes, validation plan, and explicit approval boundary.
```

The onboarding flow must preserve downstream ownership: BaseCoat can provide
the operating contract and debate format, but the downstream repository owns
its product register, users, purpose, brand, boundaries, and design decisions.

Here `debate:` is a design-mode modifier: compare evidence and options before
implementation. It does not create a second routing path or authorize writes.

The lifecycle-specific prompts for onboarding, refreshing, and removing
BaseCoat are maintained in the generated
[prompt library](../reference/prompt-library.md). Use the combined prompt above
when discovery and audit must happen before adoption, and the lifecycle prompts
when the adoption decision is already made.

## Common execution flow

Every downstream request should be understandable through this flow:

```text
User prompt
    |
    v
Parse prefix, modifiers, platform, and requested side effects
    |
    v
Select the canonical agent or skill
    |
    v
Load the asset contract: inputs, tools, dependencies, and guardrails
    |
    v
Satisfy the LOG-FIRST gate for implementation intents
    |
    v
Run the required plan, preflight, or read-only gate
    |
    v
Execute the bounded work
    |
    v
Validate against measurable criteria
    |
    v
Return the documented output and any handoff packet
```

### LOG-FIRST gate for implementation intents

Before any implementation begins for `bug:`, `feature:`, `chore:`, `refactor:`,
`test:`, or `deploy:`, the LOG-FIRST gate must be satisfied: the work is
recorded as a tracked item before code or infrastructure changes are made.
Read-only and advisory intents such as `audit:`, `spike:`, and `rca:` do not
enter this gate.

The gate is defined in
[basecoat-10-core-intent-routing.instructions.md](https://github.com/ivegamsft/basecoat/blob/main/instructions/basecoat-10-core-intent-routing.instructions.md)
and `governance.instructions.md`. Downstream users should expect an issue or
tracked record reference in the output for these intents.

### Prefix placement changes behavior

| Prompt shape | Meaning | Expected behavior |
|---|---|---|
| `bug: the sync script fails on Windows` | Standalone intent | Investigate and act now |
| `- bug: the sync script fails on Windows` | List item | Triage and log; do not implement |
| `run an audit` followed by `- feature: add retries` | Mixed request | Run the audit; log the feature |
| `audit: ... read-only` | Read-only modifier | Do not write files, issues, or PRs |
| `feature: ... no plan needed` | Explicit plan waiver | Record the waiver, then implement |
| `optimize: ... advisory-only` | Packetization only | Emit the execution packet and stop |

The canonical routing contract is
[basecoat-10-core-intent-routing.instructions.md](https://github.com/ivegamsft/basecoat/blob/main/instructions/basecoat-10-core-intent-routing.instructions.md).
The user-oriented syntax guide is
[intent-prefixes.md](intent-prefixes.md).

## Intent prompt and output matrix

Use these prompts as downstream smoke tests. Replace the example subject with
the repository-specific subject, evidence, and acceptance criteria.

| Intent | Sample downstream prompt | Flow | Expected output |
|---|---|---|---|
| `bug:` | `bug: the Windows sync script exits 1 when BASECOAT_REPO is unset; reproduce it and fix it` | Evidence first, then targeted fix and tests | Root cause, changed files, reproduction, passing validation |
| `feature:` | `feature: add audit logging to the orders API; propose the plan before editing` | Plan, confirmation, implementation, tests | Plan, implementation summary, risks, test evidence |
| `audit:` | `audit: review GitHub Actions for secret exposure; read-only` | Inventory, inspect, classify, no writes | Findings ranked by severity, evidence, remediation |
| `plan:` | `plan: prepare the next sprint from the oldest actionable issues` | Triage, dependency map, ordering | Sprint goal, issue list, dependencies, acceptance criteria |
| `optimize:` | `optimize: plan, implement, test, and release a cross-domain API change` | Normalize into a bounded packet before action | Objectives, scope, stop rules, validation, routing |
| `spike:` | `spike: compare two approaches for caching API responses; research only` | Time-boxed investigation | Options, evidence, recommendation, no implementation |
| `chore:` | `chore: remove stale local worktrees and merged remote branches safely` | Inventory, safety check, cleanup | Removed items, preserved items, verification |
| `fleet:` | `fleet: close the current sprint and execute the next dependency-ordered wave` | Coordinator preflight, plan, serialized lanes | Wave plan, lane checkpoints, merged work, blockers |
| `workflow:` | `workflow: diagnose the first failing GitHub Actions step and repair it` | Run, job, and step evidence, minimal fix, rerun | Failure cause, patch, rerun result, remaining risk |
| `actions:` | `actions: inspect pending workflow approvals and explain the policy boundary` | Query runs, approvals, policy, permissions | Run inventory, approval reason, safe action |
| `pr:` | `pr: finish PR #123, including checks, mergeability, closeout, and branch cleanup` | PR-first lifecycle triage and gated closeout | Status, blockers, merge result, cleanup evidence |
| `issue:` | `issue: triage the oldest open issues, deduplicate them, and label the actionable set` | Search, classify, link, label | Triage table, duplicate links, labels, next actions |
| `portfolio:` | `portfolio: audit issue and PR grouping, dependencies, and project linkage` | Dedupe, categorize, wire dependencies, map groups | Portfolio findings, dependency graph, project gaps |
| `release:` | `release: assess whether v4.2.1 is ready and list every remaining gate` | Version, checks, changelog, release policy | Go/no-go decision, gate evidence, release steps |
| `security:` | `security: investigate a suspected leaked credential; contain it and document evidence` | Analysis via the security path, containment via the incident-response path | Incident findings, containment, rotation plan, issue links |
| `perf:` | `perf: investigate the API latency regression and measure before changing code` | Baseline, profile, hypothesis, validate | Measurements, bottleneck, change plan, before/after evidence |
| `outage:` | `outage: production API returns 503s; stabilize service and start an RCA` | Mitigate first, preserve evidence, recover | Incident timeline, mitigation, recovery check, RCA handoff |
| `rca:` | `rca: analyze the failed deployment from run 12345; read-only` | Evidence reconstruction and hypothesis testing | Root cause, contributing factors, prevention actions |
| `deploy:` | `deploy: stage the API deployment to staging, validate it, and stop before production` | Prepare, validate, deploy staging, stop gate | Preflight, deployment result, validation, production hold |
| `azure:` | `azure: review the Azure identity and networking prerequisites for this service` | Azure preflight, architecture, validation | Prerequisites, risks, commands, readiness decision |
| `infra:` | `infra: design the network and RBAC change; do not apply it yet` | Plan and validate infrastructure change | IaC/design plan, blast radius, approval boundary |
| `architect:` | `architect: choose a multi-region Azure design for the orders API` | Options, tradeoffs, ADR-style decision | Decision, alternatives, assumptions, follow-up plan |
| `docs:` | `docs: update onboarding for the current release and verify every link` | Inspect, edit, build, link-check | Changed docs, link results, release notes |
| `chronicle:` | `chronicle: export this session's delivery lessons into an issue-ready follow-up packet` | Extract, deduplicate, classify, package | Durable story, lessons, issue candidates, memory suggestions |
| `version:` | `version: inspect the installed BaseCoat version and report drift from the published release` | Read installed source and origin, compare | Installed version, source, latest comparison, drift |
| `test:` | `test: identify missing API contract tests and propose automation` | Coverage scan, risk rank, test design | Coverage gaps, test cases, automation plan |
| `refactor:` | `refactor: simplify the routing helper without changing behavior; plan first` | Plan, preserve behavior, test | Refactor plan, diff summary, regression evidence |
| `ui:` | `ui: implement the empty-state component and verify keyboard behavior` | UX constraints, implementation, focused checks | UI changes, screenshots or checks, accessibility results |
| `ux:` | `ux: review the checkout flow for confusing recovery states` | Journey review, evidence, recommendations | Journey map, usability findings, prioritized changes |
| `ia:` | `ia: reorganize the onboarding navigation without losing existing links` | Content inventory, taxonomy, migration plan | Information model, navigation map, redirect/link plan |
| `sprint:` | `sprint: close the current sprint and produce the carryover report` | Closeout audit, metrics, carryover | Sprint summary, carryover issues, metrics, next sprint input |
| `wave:` | `wave: execute the next dependency-ordered batch, oldest eligible item first` | Dependency sort, bounded parallel work, serial merge | Wave membership, lane results, merge order, blockers |
| `autopilot:` | `autopilot: burn down the actionable backlog until blocked or complete; stop before production` | Repeated dependency-ordered cycles with stop rules | Per-cycle checkpoints, merged work, blockers, stopping reason |

## Agent and skill usage patterns

The full asset review is represented by the generated
[prompt library](../reference/prompt-library.md). Use the following patterns
to select the right primitive downstream.

| Asset family | Sample prompt | Primary flow | Expected output |
|---|---|---|---|
| Router and discovery | `Find the right BaseCoat agent for a backend API migration` | Search catalog, compare capabilities, recommend | Canonical asset, rationale, handoff prompt |
| Agent authoring | `@agent-designer audit this agent spec for routing ambiguity and missing outputs` | Inspect frontmatter and body, score contract, revise | Scorecard, concrete fixes, revised spec |
| Application development | `@backend-dev implement the orders API endpoint with tests` | Scope, implement, test, report | Code changes, tests, API notes |
| Architecture | `@solution-architect design the multi-region API topology` | Alternatives, tradeoffs, decision | Architecture decision and follow-up work |
| Quality and testing | `@code-review review PR #123 for correctness issues only` | Read diff, classify findings, report | Findings by severity with file/line evidence |
| Security | `@security-analyst assess this workflow for secret exposure; analysis only` | Threat model, inspect, rank, report | Findings, risk, recommended remediation, evidence |
| Azure and infrastructure | `@devops-engineer prepare the staging deployment and validate prerequisites` | Preflight, staged execution, validation | Readiness, commands, deployment evidence |
| Issue and sprint planning | `@sprint-planner turn these issues into a dependency-ordered wave` | Triage, dependency map, assign | Issues, labels, ordering, acceptance criteria |
| PR and branch operations | `@branch-hygiene-sweeper identify safe merged-branch cleanup` | Inventory refs, classify safety, propose/apply | Safe deletion list, preserved work, verification |
| Release operations | `@release-manager assess release readiness for v4.2.1` | Version, gates, changelog, release action | Go/no-go, release checklist, blockers |
| Documentation | `@tech-writer update the onboarding guide and verify links` | Inspect, edit, build, link-check | Documentation diff, validation, publication note |
| Memory and handoff | `@memory-promoter extract reusable delivery lessons from this session` | Select, deduplicate, package | Story update, issue-ready follow-ups, promotion candidates |

### When to use a skill instead of an agent

Use a skill when the procedure is the important unit and the active platform
already provides the execution context. Use an agent when the task needs a
specialist persona, tool selection, multi-step reasoning, or a handoff.

Examples:

```text
Use the code-review skill to review this diff and return only actionable findings.
```

```text
@orchestrator review this diff with @code-review, then route any security
findings to @security-analyst.
```

`@code-review` reports findings; it does not dispatch to other agents. Use
`@orchestrator` when a request must cross domains, because cross-domain
dispatch is the orchestrator contract.

For platform-sensitive skills, verify the declared `compatibility` before
delegating. The canonical values are documented in
[agents-skills-dev.instructions.md](https://github.com/ivegamsft/basecoat/blob/main/.github/instructions/agents-skills-dev.instructions.md).

## Output contract for downstream consumers

Unless an asset specifies a stricter format, downstream consumers should
expect these fields in the response:

| Field | Purpose |
|---|---|
| `status` | `completed`, `blocked`, `needs-confirmation`, or `read-only` |
| `scope` | What was included and excluded |
| `evidence` | Files, runs, issues, PRs, measurements, or commands used |
| `changes` | Files or external records changed, or `none` |
| `validation` | Tests, checks, builds, or explicit validation gaps |
| `handoffs` | Next agent, skill, issue, or human approval boundary |
| `stop_reason` | Why execution ended when incomplete or intentionally bounded |

Write-capable outputs must also identify the exact side effects before claiming
success. Read-only outputs must say that no changes were made.

### Example completed output

```text
Status: completed
Scope: PR #123 checks, mergeability, and merged-branch cleanup
Evidence: checks 4567 and 4568; PR #123; worktree list
Changes: merged PR #123; removed one merged local worktree and remote branch
Validation: required checks green; origin/main synchronized
Handoffs: none
Stop reason: none
```

### Example blocked output

```text
Status: blocked
Scope: current-head automated review for PR #123
Evidence: code-review workflow run 7890
Changes: none
Validation: build and test checks passed; reviewer job failed before execution
Handoffs: issue #456 tracks the runner failure
Stop reason: required review evidence could not be produced
```

## Review coverage and known gaps

The inventory reviewed all canonical assets represented by the generated
library:

- 130 agent definitions and their evaluation companions
- 133 skill definitions and their evaluation companions
- 33 canonical intent prefixes
- 128 instruction files, 60 guides, 66 reference files, and 6 prompt files

The review found these downstream-impacting gaps:

1. Inputs, outputs, dependencies, and handoffs are mostly prose rather than
   machine-readable fields.
2. Handoff targets are not consistently validated against canonical asset names.
3. `secrets-manager` is referenced by routing documentation but has no matching
   canonical agent or skill.
4. `feature:` timing differs between the canonical instruction and the guide.
5. `rca:` read-only semantics are stronger in the guide than in every routing
   table.
6. The canonical router references
   `docs/agents/MULTI_AGENT_WORKFLOWS.md`, which is not present.
7. The prompt registry is a specification, not an active runtime registry.
8. The canonical intent file and compatibility alias duplicate content and can
   drift.

These are documentation and governance follow-ups, not reasons to change the
sample prompts above. Downstream integrations should treat the canonical intent
instruction and each asset's own frontmatter as authoritative until the gaps
are reconciled.

## Downstream adoption checklist

Before shipping a downstream prompt:

1. Start with one canonical prefix or one explicit asset.
2. Name the repository or system and the target artifact.
3. State whether the request is read-only, advisory, or write-capable.
4. Include evidence when diagnosing an existing failure.
5. Include measurable acceptance criteria for implementation work.
6. State the stop boundary for deployment, production, or irreversible actions.
7. Expect the output contract above and require evidence for every claimed side effect.
8. Link the resulting issue, PR, run, or document so another agent can continue.
