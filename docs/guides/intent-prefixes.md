# Intent Prefixes

BaseCoat sessions use a structured prefix convention to communicate intent.
Every message prefix tells the AI three things at once: **what kind of work**,
**how urgent**, and **which agents to involve**.

Prefix prompts should use native SDLC nouns (workflow run, job, PR, issue,
release, version drift) to reduce routing ambiguity.

---

## The prefix vocabulary

| Prefix | Means | Timing | Routes to |
|---|---|---|---|
| `bug:` | Defect, regression, broken behavior | **Now** | `@code-review`, `@self-healing-ci` |
| `feature:` | New capability or enhancement | **Backlog** | `@sprint-planner`, `@solution-architect` |
| `audit:` | Review, assess, validate — no changes | **Now, read-only** | `@security-analyst`, `@config-auditor` |
| `plan:` | Sprint or project planning | **Now, no implementation** | `@sprint-planner`, `@product-manager` |
| `spike:` | Time-boxed investigation, no deliverable | **Now, research only** | `@solution-architect` |
| `chore:` | Maintenance, cleanup, non-functional | **Soon** | `@devops-engineer`, `@release-manager` |
| `pr:` | Pull request lifecycle handling: triage, merge readiness, build-gated closeout, and branch hygiene | **Now** | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `fleet:` | Close previous sprint, plan and execute the next sprint, triage oldest issues, audit PRs/builds, clean branches | **Now** | `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `workflow:` | GitHub Actions workflow failure triage and repair | **Now** | `@broken-build-troubleshooter`, `@self-healing-ci`, `@devops-engineer` |
| `actions:` | GitHub Actions configuration, runs, and policy checks | **Now** | `@self-healing-ci`, `@ci-failure-escalation`, `@devops-engineer` |
| `pr:` | Pull request triage, mergeability, or stale PR cleanup | **Now** | `@orphaned-pr-cleanup`, `@merge-coordinator`, `@code-review` |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | **Now** | `@issue-triage`, `@sprint-planner` |
| `release:` | Release planning, version bumping, and publication | **Now** | `@release-manager`, `@release-readiness-chair`, `@release-impact-advisor` |
| `version:` | BaseCoat version inspection and drift check | **Now** | `@release-manager`, `@devops-engineer` |
| `security:` | Security concern or vulnerability | **Now, high priority** | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation | **Now, measure first** | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | **Now, high priority** | `@rca` |
| `rca:` | Root-cause analysis of a known failure — execution suspended | **Now, read-only** | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment — azure-prepare, azure-validate, azure-deploy in sequence | **Now, staged** | `@devops-engineer` |
| `azure:` | Azure-scoped operation (auth, infra, SDK, provisioning) | **Now** — preflight first, then staged sequence | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change (IaC, networking, firewall, RBAC) | **Now** — preflight first, then staged sequence | `@devops-engineer`, `@solution-architect` |
| `architect:` | Architecture design or system-design decision | **Later** — plan before any implementation | `@solution-architect` |
| `docs:` | Documentation only | **Soon** | `@tech-writer` |
| `test:` | Test coverage gap or test failure | **Now** | `@manual-test-strategy` |
| `refactor:` | Structural improvement, no behavior change | **Later, batch** | `@code-review` |
| `ux:` | User experience or design | **Soon** | `@ux-designer` |

---

## Intent families

Each prefix belongs to an intent family. Families are useful for routing and
for selecting chain patterns.

| Family | Prefixes | Default output type |
|---|---|---|
| Delivery | `feature:`, `refactor:`, `deploy:`, `architect:` | implementation plan, code changes, or staged deployment |
| Reliability | `bug:`, `perf:`, `outage:`, `rca:` | fix, mitigation, incident analysis, or root-cause report |
| Governance | `audit:`, `security:`, `chore:` | findings, policy action, risk controls |
| GitHub Operations | `workflow:`, `actions:`, `pr:`, `issue:`, `release:`, `version:` | run triage, repo hygiene, release/version decisions |
| Planning | `plan:`, `spike:` | prioritized backlog, design notes, decision doc |
| Quality | `test:`, `docs:`, `ux:` | tests, documentation, or design artifacts |
| Infrastructure | `azure:`, `infra:`, `deploy:` | preflight advisory, IaC changes, staged deployment |

---

## Syntax matters as much as the prefix

The same prefix means different things depending on how it appears in the message.

### Standalone → act now

```text
bug: the sync script exits with code 1 on Windows when BASECOAT_REPO is unset
```

A prefix at the start of a standalone message is an immediate work order.
The AI investigates and fixes it in this session.

### Bulleted list → triage and log, not implement

```text
- bug: metrics dashboard is broken on mobile
- feature: add a getting-started prompt
- chore: clean up stale branches
```

Prefixes inside a bulleted list are **triage items**. The AI logs them
(as GitHub issues, plan notes, or backlog entries) and confirms receipt.
It does **not** start implementing.

> This is the most important distinction. A bulleted `feature:` means
> *"add this to the backlog."* It does not mean *"build this now."*

### Mixed message → preamble is immediate, list is triage

```text
run an audit against the CI workflows and log issues

- feature: add retry logic to sync.sh
- bug: secret-scan.yml always exits 0
```

The preamble instruction ("run an audit") executes now.
The bulleted items are logged. The AI returns audit findings plus a summary
of what was filed. It waits for direction before starting any of the list items.

---

## Timing modifiers

These words in a message override the default timing of any prefix:

| Word | Effect |
|---|---|
| `now`, `immediately`, `urgent` | Promote to immediate, even `feature:` |
| `later`, `backlog`, `next sprint` | Defer, even `bug:` |
| `no changes`, `read-only` | Analysis only, suppress all implementation |
| `log it`, `file an issue` | Log and stop; do not implement |
| `just document` | Documentation output only; no code changes |

---

## Plan-first enforcement

For `feature:`, `refactor:`, and `architect:` prefixes, a planning step is
required before implementation begins whenever the work spans multiple files
or involves design decisions.

The expected flow:

1. Emit a plan (scope, approach, risks, verification criteria).
2. Present it and wait for confirmation.
3. Implement only after the plan is confirmed.

The user can waive planning explicitly ("no plan needed", "skip planning",
"implement directly"). Record the waiver so downstream agents respect it.

### Sprint-style request nudge

When the user asks to "plan and execute the next sprint" or similar:

1. Route to `@sprint-planner` first.
2. Present the sprint plan and wait for confirmation.
3. Only then begin execution with the oldest actionable item.

---

## Azure preflight

Before any `azure:`, `infra:`, or `deploy:` operation, emit this advisory:

```text
Azure preflight: ci-firewall and rbac-authentication checks apply.
See instructions/ci-firewall.instructions.md and instructions/rbac-authentication.instructions.md.
```

Then verify:

- **CI Firewall** — workflow accesses firewalled Azure resources? Confirm the
  single-job runner IP pattern (`instructions/ci-firewall.instructions.md`)
  is in place before deploying.
- **RBAC Authentication** — change provisions or configures Azure resources?
  Confirm RBAC-only auth (`instructions/rbac-authentication.instructions.md`)
  before proceeding.

The advisory is non-blocking unless a firewall or RBAC gap is found, in which
case surface the finding and wait for explicit user confirmation.

---

## Audit mode is always read-only

`audit:` never makes changes unless the user adds "and fix" or "resolve."

```text
audit: run a say-vs-do check on the CI workflows
```

→ Returns findings. Logs issues if asked. Waits.

```text
audit: run impeccable against GH Pages, log issues, and resolve
```

→ Runs audit, logs issues, then implements fixes.

---

## Why this convention exists

Working in a long session with many items in flight, prefixes let you:

- **Drop items into the backlog mid-conversation** without losing flow
- **Signal urgency without context-switching** — the AI knows `security:` means
  stop and address it, `chore:` means batch it
- **Audit without side effects** — `audit:` is a safe way to ask "what's wrong
  here?" without triggering changes
- **Control sprint scope** — a bulleted list of `feature:` items at the end of
  a message becomes the next sprint's backlog, not this session's work

---

## Outage routing

When a user says a service is broken, dead, down, or not responding, normalize
that request to `outage:` and route it to the RCA agent.

| Alias | Normalized intent |
|---|---|
| `broken` | `outage:` |
| `broke` | `outage:` |
| `dead` | `outage:` |
| `site down` | `outage:` |
| `down` | `outage:` |
| `not responding` | `outage:` |
| `incident` | `outage:` |
| `it's broken` | `outage:` |
| `nothing works` | `outage:` |

Use `@rca` for the deep-dive investigation after the active incident is stable.

---

## RCA routing

`rca:` suspends all execution. Use it when you want to diagnose before retrying.

| Alias | Normalized intent |
|---|---|
| `stop and rca` | `rca:` |
| `why is it failing` | `rca:` |
| `same error` (after a prior failure) | `rca:` |
| `still broken` (after a retry) | `rca:` |
| deployment retried 3 or more times | `rca:` (hard block) |

To resume execution after RCA, re-issue a `deploy:` or `outage:` intent explicitly
once the root cause is confirmed.

---

## Deployment routing

`deploy:` enforces the staged deployment sequence and prevents skipping validation.

**Required chain:**

1. `azure-prepare` — scaffold IaC and validate configuration
2. `azure-validate` — pre-deployment checks, no resource changes
3. `azure-deploy` — provision and deploy

If the same deployment step fails twice, the session automatically enters RCA mode.

Example prompt:

```text
deploy: follow azure-prepare -> azure-validate -> azure-deploy exactly; do not deploy until validated
```

See [`docs/reference/guardrails/deployment-rca.md`](../reference/guardrails/deployment-rca.md)
for retry caps, path lock, and bootstrap immutability rules.

---

## PR routing

`pr:` is the direct intent for PR lifecycle execution.

### Default sequence

1. Triage stale or blocked pull requests with `@orphaned-pr-cleanup`.
2. Validate merge readiness and ordering with `@merge-coordinator`.
3. Verify required CI status before closure; if builds are red, route to `@broken-build-troubleshooter`.
4. Run `@branch-hygiene-sweeper` after merge/close actions to prune only safe branches.

### Guardrails

- Do not close or mark complete while required builds are still pending.
- If required builds fail, keep the PR open and attach failure evidence.
- Only run branch cleanup for branches tied to merged/closed PRs with required builds passing.
- Prefer serial merges for overlapping branches to reduce conflict churn.

---

## Fleet routing

`fleet:` is the shortcut intent for a sprint-execution batch that combines closeout, planning, oldest-first issue triage, PR/build auditing, and branch cleanup.

### Normalized examples

| User phrasing | Normalized intent |
|---|---|
| `Fleet deployed: use basecoat...` | `fleet:` |
| `fleet: plan and execute the sprint` | `fleet:` |
| `use basecoat for fleet mode` | `fleet:` |

### Fleet chain

- `@sprint-closeout-auditor`
- `@issue-triage`
- `@broken-build-troubleshooter`
- `@sprint-planner`
- `@branch-hygiene-sweeper`

---

## GitHub-native deterministic routing

`workflow:`, `actions:`, `pr:`, `issue:`, `release:`, and `version:` are
deterministic routes. If the prefix is present, do not ask a follow-up
disambiguation question before first evidence collection.

### Contract

1. `workflow:` / `actions:`: fetch failing run and job evidence first, then fix,
   then rerun affected scope.
2. `pr:`: inspect PR state first (mergeability, checks, review blockers), then act.
3. `issue:`: inspect issue state first (labels, stale status, ownership), then act.
4. `release:`: start from release/version source-of-truth, then perform release steps.
5. `version:`: read installed downstream version first; compare to latest published
   release only when install origin is published BaseCoat.

---

## The instruction file

This convention is codified in
[`instructions/intent-routing.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/intent-routing.instructions.md).

When BaseCoat is synced to your repo, this instruction is loaded by Copilot
automatically and applies to all conversations. You can adopt this prefix
convention in your own team immediately — no configuration required.

---

## Examples

### Good: bug in a standalone message

```text
bug: the lint workflow silently passes on instructions with trailing spaces
```

AI fixes it now.

### Good: features in a bulleted list

```text
- feature: add retry logic to sync.sh
- feature: add a prompt for onboarding new repos
- feature: support BASECOAT_EXCLUDE env var
```

AI logs three backlog items and reports what was filed.

### Common mistake: bulleted feature treated as immediate

```text
- feature: add a getting-started prompt
```

Wrong response: "Here is the getting-started prompt I just created..."
Correct response: "Logged as a backlog item. Should I add it to the current sprint?"

### Combine audit and fix explicitly

```text
audit: check all agent files for missing Workflow sections, log issues, fix them
```

AI audits → logs → fixes in one pass because "fix them" was explicit.

---

## Prompting with proper vocabulary

Use a compact, deterministic shape when writing prompts:

```text
<prefix>: <objective>
scope: <in/out boundaries>
constraints: <non-negotiables>
deliverable: <artifact to return>
evidence: <what to prove>
next-hop: <agent name or none>
```

### Delivery example

```text
feature: add plan-first lint checks for new agent files
scope: instructions/agents.instructions.md and tests only
constraints: no workflow changes
deliverable: updated instruction rule plus test case
evidence: failing then passing test output
next-hop: code-review
```

### Governance example

```text
audit: evaluate all skills for missing USE FOR / DO NOT USE FOR sections
scope: skills/**/SKILL.md
constraints: read-only; log issues but do not edit files
deliverable: severity-ranked findings table
evidence: file paths and missing-section counts
next-hop: none
```

---

## Chain recipes by intent

Use these default chains unless there is a task-specific reason to override.

| Intent | Chain | Outcome |
|---|---|---|
| `feature:` | `plan: -> solution-architect -> backend-dev/frontend-dev -> code-review` | plan-first, then design to implementation with review |
| `refactor:` | `plan: -> code-review -> performance-analyst` | plan-first, then structural improvement |
| `architect:` | `plan: -> solution-architect` | plan-first, then design decision |
| `bug:` | `code-review -> self-healing-ci -> guardrail` | defect isolation and safe fix |
| `outage:` | `rca -> incident-responder -> sre-engineer` | triage, containment, and reliability follow-up |
| `rca:` | `rca -> config-auditor` | root-cause diagnosis, execution suspended |
| `azure:` | `azure-preflight -> azure-prepare -> azure-validate -> azure-deploy` | preflight advisory, then staged deployment |
| `infra:` | `azure-preflight -> azure-prepare -> azure-validate -> azure-deploy` | preflight advisory, then staged deployment |
| `deploy:` | `azure-prepare -> azure-validate -> azure-deploy` | staged deployment with pre-flight validation |
| `security:` | `security-analyst -> policy-as-code-compliance -> guardrail` | remediation and policy validation |
| `plan:` | `product-manager -> sprint-planner` | scoped sprint-ready backlog |
| `test:` | `manual-test-strategy -> strategy-to-automation` | test strategy and automation candidates |

When chaining, each handoff prompt should include:

1. Intent statement.
2. What is done.
3. What remains.
4. Constraints that must carry forward.
5. Expected output contract.

---

## Design notes

These conventions intentionally prefer:

- **Intent-first routing** over asking users to pick an agent manually.
- **Canonical verbs** (`triage`, `classify`, `validate`, `escalate`, `handoff`)
  over ambiguous verbs.
- **Standard chains** over ad hoc sequencing.

This keeps prompting predictable and improves routing eval reliability.
